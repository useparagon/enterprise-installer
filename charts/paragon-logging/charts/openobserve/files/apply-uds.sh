#!/bin/sh
# OpenObserve UDS apply hook (PARA-20444 / PARA-24453) — POSIX sh for Alpine /bin/sh.
#
# When to run: Helm post-install / post-upgrade on paragon-logging (OpenObserve must be up).
#
# Process:
#   1. Load the desired field list from openobserve-uds-schema.json (chart files/).
#   2. GET /api/default/streams?type=logs&fetchSchema=false (settings only; never the
#      inferred field list — that payload can be tens of MB and times out).
#   3. If settings.defined_schema_fields already matches desired names, skip PUT.
#   4. Otherwise build a PUT body from the list-API settings object:
#        - add: every desired field name + field definitions
#        - remove: defined_schema_fields / uds_schema names on the server but not desired
#   5. PUT stream settings, then GET the list again and fail unless defined_schema_fields
#      matches the JSON. Do not GET /schema (historical inferred fields stay huge after UDS).
#
# Transient HTTP failures on the settings fetch warn and exit 0 so an atomic Helm
# upgrade cannot roll back paragon-logging when OpenObserve is still settling.
# 401/403 still fail fast. Curl bodies are written to files, not shell variables.
set -eu

LOG_PREFIX="[openobserve-uds]"
DESIRED_SCHEMA_FILE="${DESIRED_SCHEMA_FILE:-/uds/openobserve-uds-schema.json}"
O2_HOST="${O2_HOST:-http://openobserve:5080}"
HEALTH_WAIT_SECONDS="${HEALTH_WAIT_SECONDS:-120}"
AUTH_CURL_MAX_TIME="${AUTH_CURL_MAX_TIME:-600}"
AUTH_CURL_RETRIES="${AUTH_CURL_RETRIES:-5}"
WORKDIR="${TMPDIR:-/tmp}/uds-apply-$$"
STREAMS_URL=""

log() {
  echo "${LOG_PREFIX} $*"
}

die() {
  echo "${LOG_PREFIX} error: $*" >&2
  exit 1
}

warn_skip() {
  echo "${LOG_PREFIX} warning: $*" >&2
  log "skipping UDS apply so the Helm release is not rolled back"
  log "done (skipped)"
  exit 0
}

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT
mkdir -p "$WORKDIR"

if [ -z "$ZO_ROOT_USER_EMAIL" ] || [ -z "$ZO_ROOT_USER_PASSWORD" ]; then
  die "ZO_ROOT_USER_EMAIL and ZO_ROOT_USER_PASSWORD required"
fi

if [ ! -f "$DESIRED_SCHEMA_FILE" ]; then
  die "desired schema not found: ${DESIRED_SCHEMA_FILE}"
fi

O2_HOST="${O2_HOST%/}"
STREAMS_URL="${O2_HOST}/api/default/streams?type=logs&fetchSchema=false"

expected_count="$(jq '.schema | length' "$DESIRED_SCHEMA_FILE")"
log "starting UDS apply for stream paragon (desired fields: ${expected_count})"
log "openobserve endpoint: ${O2_HOST}"

# Authenticated curl. Extra args, then URL last. Writes body to $1, prints HTTP status.
# Does not log credentials.
curl_auth_status() {
  _out="$1"
  shift
  curl -sS -o "$_out" -w '%{http_code}' --connect-timeout 10 --max-time "$AUTH_CURL_MAX_TIME" \
    -u "$ZO_ROOT_USER_EMAIL:$ZO_ROOT_USER_PASSWORD" "$@"
}

is_transient_http() {
  case "$1" in
    000|408|425|429|500|502|503|504) return 0 ;;
    *) return 1 ;;
  esac
}

# Retry transient failures. 401/403 fail immediately. HTTP status is stored in
# $WORKDIR/http-status so callers can read it without capturing stdout logs.
auth_curl_file() {
  _out="$1"
  shift
  _attempt=1
  _delay=2
  while [ "$_attempt" -le "$AUTH_CURL_RETRIES" ]; do
    _status="$(curl_auth_status "$_out" "$@")" || _status="000"
    echo "$_status" >"$WORKDIR/http-status"
    case "$_status" in
      200|201|204) return 0 ;;
      401|403)
        die "OpenObserve rejected credentials (HTTP ${_status}). Run scripts/migrate-openobserve-password.sh (--hoop or --o2-host) after terraform apply."
        ;;
    esac
    if [ "$_attempt" -ge "$AUTH_CURL_RETRIES" ]; then
      return 1
    fi
    if is_transient_http "$_status"; then
      log "HTTP ${_status}; retry ${_attempt}/${AUTH_CURL_RETRIES} in ${_delay}s"
      sleep "$_delay"
      _delay=$((_delay * 2))
      _attempt=$((_attempt + 1))
    else
      return 1
    fi
  done
  echo "000" >"$WORKDIR/http-status"
  return 1
}

verify_auth() {
  _probe="$WORKDIR/auth-probe"
  _status="$(curl_auth_status "$_probe" "$STREAMS_URL")" || _status="000"
  case "$_status" in
    200) ;;
    401|403)
      die "OpenObserve rejected credentials (HTTP ${_status}). Run scripts/migrate-openobserve-password.sh (--hoop or --o2-host) after terraform apply."
      ;;
    *) die "auth probe failed: GET /api/default/streams returned HTTP ${_status}" ;;
  esac
}

# Stream settings from the list API (no inferred schema). Empty file if paragon is missing.
fetch_paragon_stream() {
  _dest="$1"
  _raw="$WORKDIR/streams.json"
  if ! auth_curl_file "$_raw" "$STREAMS_URL"; then
    return 1
  fi
  if ! jq -ce '.list[] | select(.name == "paragon")' "$_raw" >"$_dest"; then
    return 1
  fi
  return 0
}

schema_matches_desired() {
  jq -e --slurpfile d "$DESIRED_SCHEMA_FILE" '
    (.settings.defined_schema_fields // []) as $cur |
    [$d[0].schema[].name] as $want |
    (($want | length) == ($cur | length)) and
    ($want | all(. as $n | $cur | index($n) != null))
  ' "$1" >/dev/null
}

print_schema_counts() {
  _label="$1"
  _file="$2"
  _defined="$(jq '(.settings.defined_schema_fields // []) | length' "$_file")"
  log "${_label}: defined_schema_fields=${_defined} (expected ${expected_count})"
}

log "waiting for ${O2_HOST}/healthz (max ${HEALTH_WAIT_SECONDS}s)..."
elapsed=0
until curl -sf --connect-timeout 5 --max-time 10 "${O2_HOST}/healthz" >/dev/null 2>&1; do
  if [ "$elapsed" -ge "$HEALTH_WAIT_SECONDS" ]; then
    die "OpenObserve not ready after ${HEALTH_WAIT_SECONDS}s"
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
log "openobserve is healthy"

log "verifying credentials against OpenObserve API"
verify_auth
log "credentials accepted"

log "fetching current stream settings (list API, fetchSchema=false)"
current="$WORKDIR/current.json"
if ! fetch_paragon_stream "$current"; then
  warn_skip "failed to fetch stream paragon settings (timeout or transient error)"
fi
print_schema_counts "before apply" "$current"

if schema_matches_desired "$current"; then
  log "UDS already matches desired schema; skipping PUT"
  log "done (no changes)"
  exit 0
fi

log "schema drift detected; building PUT payload"
payload="$WORKDIR/payload.json"
# jq: compute add/remove vs desired list (same semantics as o2-apply-uds.ts).
# List responses omit uds_schema; remove_fields is then [].
jq -c --slurpfile d "$DESIRED_SCHEMA_FILE" '
  . as $current |
  $d[0].schema as $desired |
  ($desired | map(.name)) as $add_names |
  (($current.settings.defined_schema_fields // []) | map(select(. as $n | $add_names | index($n) | not))) as $remove_names |
  (($current.uds_schema // []) | map(select(.name as $n | $add_names | index($n) | not))) as $remove_fields |
  {
    defined_schema_fields: {
      add: $add_names,
      remove: $remove_names
    },
    fields: {
      add: $desired,
      remove: $remove_fields
    }
  }
' "$current" >"$payload"

add_names="$(jq '.defined_schema_fields.add | length' "$payload")"
remove_names="$(jq '.defined_schema_fields.remove | length' "$payload")"
remove_fields="$(jq '.fields.remove | length' "$payload")"
log "PUT payload: add ${add_names} defined_schema_fields, remove ${remove_names} names, remove ${remove_fields} field objects"

log "applying UDS via PUT ${O2_HOST}/api/default/streams/paragon/settings"
put_out="$WORKDIR/put.json"
if ! auth_curl_file "$put_out" -X PUT -H "Content-Type: application/json" -d @"$payload" \
  "${O2_HOST}/api/default/streams/paragon/settings"; then
  die "PUT stream settings failed (HTTP $(cat "$WORKDIR/http-status"))"
fi

log "verifying settings after PUT"
updated="$WORKDIR/updated.json"
if ! fetch_paragon_stream "$updated"; then
  die "failed to re-fetch stream paragon after PUT"
fi
print_schema_counts "after apply" "$updated"

defined_count="$(jq '(.settings.defined_schema_fields // []) | length' "$updated")"

if [ "$defined_count" -ne "$expected_count" ]; then
  die "post-PUT defined_schema_fields count ${defined_count} != expected ${expected_count}"
fi

if ! schema_matches_desired "$updated"; then
  die "post-PUT schema field names do not match desired list"
fi

log "UDS apply succeeded: ${defined_count} defined_schema_fields"
log "done"
