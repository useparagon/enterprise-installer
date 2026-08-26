#!/usr/bin/env node

// OpenObserve user-defined schema (UDS) apply hook (PARA-20444 / PARA-24453).
//
// Runs as a Helm post-install / post-upgrade Job on paragon-logging and makes the
// `paragon` logs stream use the field list in openobserve-uds-schema.json.
//
// The apply is deliberately two requests. OpenObserve only keeps
// `defined_schema_fields` that already exist as columns on the stream, silently
// dropping the rest (see save_stream_settings in src/service/stream.rs). On a
// fresh install Fluent Bit has only taught the stream a handful of fields, so a
// combined `fields` + `defined_schema_fields` PUT lands a near-empty UDS. So:
//
//   1. PUT { fields: { add } }                  -> creates the columns
//   2. PUT { defined_schema_fields: { add, remove } }  -> selects them
//
// Fields OpenObserve still drops are reported by name so a partial apply is
// visible in the Job's pod logs rather than silent.
//
// Only a broken configuration fails the hook (missing credentials, unreadable or
// invalid schema file, rejected credentials, a request OpenObserve calls invalid).
// Everything else — timeouts, 5xx, a stream that never appears, a partial
// apply — logs a warning and exits 0 so an atomic Helm upgrade cannot roll
// paragon-logging back over a best-effort schema tweak.

import { readFileSync } from 'node:fs';

const LOG_PREFIX = '[openobserve-uds]';

// Columns OpenObserve manages itself. Never send these as removals.
const INTERNAL_COLUMNS = new Set(['_all', '_all_values', '_original', '_o2_id']);

const TRANSIENT_STATUSES = new Set([408, 425, 429, 500, 502, 503, 504]);

// How many field names to print before summarizing the rest.
const MAX_FIELDS_LOGGED = 25;

// Arrow type names OpenObserve parses, matched case-sensitively. An unknown name
// comes back as an opaque HTTP 500 ("invalid data type"), so reject it locally
// where the message can name the offending field.
const ARROW_TYPES = new Set([
  'Binary',
  'Boolean',
  'Date32',
  'Float32',
  'Float64',
  'Int32',
  'Int64',
  'Utf8',
]);

/**
 * @typedef {Object} DesiredField
 * @property {string} name
 * @property {string} type Arrow data type name, e.g. "Utf8" or "Int64".
 */

/** Configuration is wrong and retrying cannot help. Fails the Helm hook. */
class ConfigError extends Error {}

/** Best effort did not fully succeed. Warns and exits 0. */
class TransientError extends Error {}

const log = (message) => console.log(`${LOG_PREFIX} ${message}`);
const warn = (message) => console.warn(`${LOG_PREFIX} warning: ${message}`);

// Used while reading configuration, before the ConfigError handler is in scope.
function exitWithConfigError(message) {
  console.error(`${LOG_PREFIX} error: ${message}`);
  process.exit(1);
}

function intFromEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') {
    return fallback;
  }
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 0) {
    exitWithConfigError(`${name} must be a non-negative integer, got "${raw}"`);
  }
  return value;
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    exitWithConfigError(`${name} is required`);
  }
  return value;
}

const config = {
  host: (process.env.O2_HOST || 'http://openobserve:5080').replace(/\/+$/, ''),
  org: process.env.O2_ORG || 'default',
  stream: process.env.O2_STREAM || 'paragon',
  schemaFile: process.env.DESIRED_SCHEMA_FILE || '/uds/openobserve-uds-schema.json',
  healthWaitSeconds: intFromEnv('HEALTH_WAIT_SECONDS', 60),
  streamWaitSeconds: intFromEnv('STREAM_WAIT_SECONDS', 180),
  requestTimeoutSeconds: intFromEnv('REQUEST_TIMEOUT_SECONDS', 60),
  requestRetries: intFromEnv('REQUEST_RETRIES', 5),
  applyAttempts: Math.max(1, intFromEnv('APPLY_ATTEMPTS', 3)),
  // Stay under the Job's activeDeadlineSeconds and the Helm release timeout.
  // A deadline or Helm timeout kill marks the Job failed and rolls back.
  budgetSeconds: intFromEnv('TOTAL_BUDGET_SECONDS', 360),
};

// Read up front so a missing secret key fails before the health wait.
const credentials = Buffer.from(
  `${requireEnv('ZO_ROOT_USER_EMAIL')}:${requireEnv('ZO_ROOT_USER_PASSWORD')}`,
).toString('base64');

const startedAt = Date.now();
const budgetEndsAt = startedAt + config.budgetSeconds * 1000;

const secondsLeft = () => Math.max(0, Math.round((budgetEndsAt - Date.now()) / 1000));
const budgetExhausted = () => Date.now() >= budgetEndsAt;
const sleep = (seconds) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));

/**
 * Print a field list, truncated so a 494-field diff stays readable.
 * @param {string[]} names
 */
function formatFieldList(names) {
  const shown = names.slice(0, MAX_FIELDS_LOGGED).join(', ');
  const hidden = names.length - MAX_FIELDS_LOGGED;
  return hidden > 0 ? `${shown}, ... (+${hidden} more)` : shown;
}

/**
 * @returns {DesiredField[]}
 */
function loadDesiredSchema() {
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(config.schemaFile, 'utf8'));
  } catch (error) {
    throw new ConfigError(`cannot read ${config.schemaFile}: ${error.message}`);
  }

  if (!Array.isArray(parsed?.schema) || parsed.schema.length === 0) {
    throw new ConfigError(`${config.schemaFile} must contain a non-empty "schema" array`);
  }

  const byName = new Map();
  for (const field of parsed.schema) {
    if (typeof field?.name !== 'string' || !field.name) {
      throw new ConfigError(`${config.schemaFile} has a schema entry without a "name"`);
    }
    if (typeof field?.type !== 'string' || !field.type) {
      throw new ConfigError(`${config.schemaFile} entry "${field.name}" has no "type"`);
    }
    if (!ARROW_TYPES.has(field.type)) {
      throw new ConfigError(
        `${config.schemaFile} entry "${field.name}" has unsupported type "${field.type}"; ` +
          `expected one of ${[...ARROW_TYPES].join(', ')}`,
      );
    }
    byName.set(field.name, { name: field.name, type: field.type });
  }

  const duplicates = parsed.schema.length - byName.size;
  if (duplicates > 0) {
    warn(`${config.schemaFile} has ${duplicates} duplicate field name(s); using the last of each`);
  }
  return [...byName.values()];
}

/**
 * One authenticated request. Body is read into a string only because the
 * endpoints used here are small; the inferred field list is never fetched.
 * @returns {Promise<{ status: number, body: string }>}
 */
async function request(path, { method = 'GET', payload } = {}) {
  const headers = { Authorization: `Basic ${credentials}` };
  if (payload !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  const response = await fetch(`${config.host}${path}`, {
    method,
    headers,
    body: payload === undefined ? undefined : JSON.stringify(payload),
    signal: AbortSignal.timeout(config.requestTimeoutSeconds * 1000),
  });

  return { status: response.status, body: await response.text() };
}

/**
 * Retry network errors and transient statuses with exponential backoff, bounded
 * by the overall budget. 401/403 and other 4xx are returned to the caller, which
 * decides whether they are fatal.
 * @returns {Promise<{ status: number, body: string }>}
 */
async function requestWithRetry(description, path, options = {}) {
  let delaySeconds = 2;

  for (let attempt = 1; ; attempt += 1) {
    let result;
    let failure;
    try {
      result = await request(path, options);
      if (result.status < 400 || !TRANSIENT_STATUSES.has(result.status)) {
        return result;
      }
      failure = `HTTP ${result.status}`;
    } catch (error) {
      failure =
        error.name === 'TimeoutError'
          ? `timed out after ${config.requestTimeoutSeconds}s`
          : error.message;
    }

    if (attempt >= config.requestRetries) {
      throw new TransientError(`${description} failed after ${attempt} attempt(s): ${failure}`);
    }
    if (delaySeconds >= secondsLeft()) {
      throw new TransientError(`${description} failed (${failure}) and the time budget is exhausted`);
    }
    log(`${description}: ${failure}; retry ${attempt}/${config.requestRetries - 1} in ${delaySeconds}s`);
    await sleep(delaySeconds);
    delaySeconds *= 2;
  }
}

async function waitForHealth() {
  log(`waiting for ${config.host}/healthz (up to ${config.healthWaitSeconds}s)`);
  const deadline = Date.now() + config.healthWaitSeconds * 1000;

  for (;;) {
    try {
      const response = await fetch(`${config.host}/healthz`, {
        signal: AbortSignal.timeout(10_000),
      });
      if (response.ok) {
        log('openobserve is healthy');
        return;
      }
    } catch {
      // Not up yet.
    }
    if (Date.now() >= deadline || budgetExhausted()) {
      throw new TransientError(`openobserve was not ready within ${config.healthWaitSeconds}s`);
    }
    await sleep(2);
  }
}

/**
 * Current UDS field names for the stream, or null if the stream does not exist.
 * Uses the list API with fetchSchema=false: the inferred field list can be tens
 * of MB on a high-traffic deployment and is not needed here.
 * @returns {Promise<string[] | null>}
 */
async function fetchDefinedSchemaFields() {
  const path = `/api/${config.org}/streams?type=logs&fetchSchema=false`;
  const { status, body } = await requestWithRetry('list streams', path);

  if (status === 401 || status === 403) {
    throw new ConfigError(
      `openobserve rejected the credentials (HTTP ${status}). ` +
        'Run scripts/migrate-openobserve-password.sh (--hoop or --o2-host) after terraform apply.',
    );
  }
  if (status !== 200) {
    throw new TransientError(`list streams returned HTTP ${status}: ${body.slice(0, 500)}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch (error) {
    throw new TransientError(`list streams returned invalid JSON: ${error.message}`);
  }

  const stream = (parsed?.list || []).find((entry) => entry?.name === config.stream);
  return stream ? stream.settings?.defined_schema_fields || [] : null;
}

/**
 * @returns {Promise<string[]>} UDS fields once the stream exists.
 */
async function waitForStream() {
  const deadline = Date.now() + config.streamWaitSeconds * 1000;

  for (;;) {
    const fields = await fetchDefinedSchemaFields();
    if (fields !== null) {
      return fields;
    }
    const remaining = Math.round((deadline - Date.now()) / 1000);
    if (remaining <= 0 || budgetExhausted()) {
      throw new TransientError(
        `stream "${config.stream}" did not appear within ${config.streamWaitSeconds}s; ` +
          'Fluent Bit creates it on its first flush, so this usually means no logs have shipped yet',
      );
    }
    log(`stream "${config.stream}" not created yet; waiting (${remaining}s remaining)`);
    await sleep(Math.min(5, remaining));
  }
}

async function putSettings(description, payload) {
  const path = `/api/${config.org}/streams/${config.stream}/settings`;
  const { status, body } = await requestWithRetry(description, path, { method: 'PUT', payload });

  if (status === 401 || status === 403) {
    throw new ConfigError(`openobserve rejected the credentials on ${description} (HTTP ${status})`);
  }
  if (status === 404) {
    throw new TransientError(`stream "${config.stream}" disappeared during ${description} (HTTP 404)`);
  }
  if (status >= 400) {
    // 400/409/422 mean OpenObserve considers the payload itself invalid (bad
    // data type, UDS field count over ZO_USER_DEFINED_SCHEMA_MAX_FIELDS, ...).
    // Retrying an identical request will not help, so fail the hook loudly.
    throw new ConfigError(`${description} rejected with HTTP ${status}: ${body.slice(0, 500)}`);
  }
}

/**
 * One two-phase apply. Returns the UDS field names OpenObserve stored.
 * @param {DesiredField[]} desired
 * @param {string[]} current
 * @returns {Promise<string[]>}
 */
async function applyOnce(desired, current) {
  const desiredNames = desired.map((field) => field.name);
  const wanted = new Set(desiredNames);
  const stale = current.filter((name) => !wanted.has(name) && !INTERNAL_COLUMNS.has(name));

  log(`step 1/2: creating ${desired.length} column(s) on stream "${config.stream}"`);
  await putSettings('create stream columns', { fields: { add: desired } });

  log(
    `step 2/2: selecting ${desiredNames.length} field(s) as the user-defined schema` +
      (stale.length > 0 ? `, dropping ${stale.length} no longer desired` : ''),
  );
  await putSettings('set defined_schema_fields', {
    defined_schema_fields: { add: desiredNames, remove: stale },
  });

  const applied = await fetchDefinedSchemaFields();
  if (applied === null) {
    throw new TransientError(`stream "${config.stream}" disappeared after the apply`);
  }
  return applied;
}

/**
 * Log what the apply achieved and return the desired fields OpenObserve dropped.
 * @param {DesiredField[]} desired
 * @param {string[]} applied UDS field names after the apply.
 * @param {string[]} current UDS field names before the apply.
 * @returns {string[]}
 */
function reportOutcome(desired, applied, current) {
  const appliedSet = new Set(applied);
  const previous = new Set(current);
  const desiredNames = desired.map((field) => field.name);
  const wanted = new Set(desiredNames);

  const missing = desiredNames.filter((name) => !appliedSet.has(name));
  const added = desiredNames.filter((name) => appliedSet.has(name) && !previous.has(name));
  const extra = applied.filter((name) => !wanted.has(name) && !INTERNAL_COLUMNS.has(name));

  log(
    `stream "${config.stream}" user-defined schema: ${applied.length} field(s) selected ` +
      `of ${desiredNames.length} desired`,
  );
  log(`  newly added this run: ${added.length}`);
  log(`  already selected before this run: ${desiredNames.length - missing.length - added.length}`);

  if (extra.length > 0) {
    log(`  selected but not in the desired list: ${extra.length} (${formatFieldList(extra)})`);
  }
  if (missing.length > 0) {
    log(`  not selected: ${missing.length} (${formatFieldList(missing)})`);
  }
  return missing;
}

async function main() {
  const desired = loadDesiredSchema();
  log(`openobserve endpoint: ${config.host}`);
  log(`stream: ${config.org}/${config.stream}`);
  log(`desired user-defined schema: ${desired.length} field(s) from ${config.schemaFile}`);

  await waitForHealth();

  let current = await waitForStream();
  log(`stream "${config.stream}" currently has ${current.length} user-defined schema field(s)`);

  const selected = new Set(current);
  const alreadyMatches =
    current.length === desired.length && desired.every((field) => selected.has(field.name));
  if (alreadyMatches) {
    log('user-defined schema already matches the desired list; nothing to apply');
    return;
  }

  for (let attempt = 1; attempt <= config.applyAttempts; attempt += 1) {
    log(`apply attempt ${attempt}/${config.applyAttempts}`);
    const applied = await applyOnce(desired, current);
    const missing = reportOutcome(desired, applied, current);

    if (missing.length === 0) {
      log('user-defined schema applied successfully');
      return;
    }

    current = applied;
    if (attempt === config.applyAttempts || secondsLeft() < 30) {
      throw new TransientError(
        `${missing.length} field(s) were dropped by OpenObserve after ${attempt} attempt(s). ` +
          'They will be applied by the next paragon-logging upgrade.',
      );
    }
    log(`retrying in 10s (${secondsLeft()}s of budget left)`);
    await sleep(10);
  }
}

try {
  await main();
  log(`done in ${Math.round((Date.now() - startedAt) / 1000)}s`);
} catch (error) {
  if (error instanceof ConfigError) {
    console.error(`${LOG_PREFIX} error: ${error.message}`);
    process.exit(1);
  }
  warn(error instanceof TransientError ? error.message : `unexpected failure: ${error.stack}`);
  log('exiting 0 so the paragon-logging release is not rolled back');
  log(`done (incomplete) in ${Math.round((Date.now() - startedAt) / 1000)}s`);
}
