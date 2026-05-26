#!/bin/sh
# OpenObserve UDS apply hook (PARA-20444) — POSIX sh for Alpine /bin/sh.
#
# When to run: Helm post-install / post-upgrade on paragon-logging (OpenObserve must be up).
#
# Process:
#   1. Load the desired field list from openobserve-uds-schema.json (chart files/).
#   2. GET the live "paragon" logs stream schema from OpenObserve.
#   3. If settings.defined_schema_fields already matches desired names, skip PUT (idempotent).
#   4. Otherwise build a PUT body:
#        - add: every desired field name + field definitions
#        - remove: names/types present on the server but not in the desired list
#   5. PUT stream settings, then GET again and fail unless counts match the JSON.
#
# All progress is written to stdout for hook Job logs (kubectl logs / cluster events).
set -eu

LOG_PREFIX="[openobserve-uds]"
DESIRED_SCHEMA_FILE="${DESIRED_SCHEMA_FILE:-/uds/openobserve-uds-schema.json}"
O2_HOST="${O2_HOST:-http://openobserve:5080}"
HEALTH_WAIT_SECONDS="${HEALTH_WAIT_SECONDS:-120}"

log() {
  echo "${LOG_PREFIX} $*"
}

die() {
  echo "${LOG_PREFIX} error: $*" >&2
  exit 1
}

if [ -z "$ZO_ROOT_USER_EMAIL" ] || [ -z "$ZO_ROOT_USER_PASSWORD" ]; then
  die "ZO_ROOT_USER_EMAIL and ZO_ROOT_USER_PASSWORD required"
fi

if [ ! -f "$DESIRED_SCHEMA_FILE" ]; then
  die "desired schema not found: ${DESIRED_SCHEMA_FILE}"
fi

O2_HOST="${O2_HOST%/}"

expected_count="$(jq '.schema | length' "$DESIRED_SCHEMA_FILE")"
log "starting UDS apply for stream paragon (desired fields: ${expected_count})"
log "openobserve endpoint: ${O2_HOST}"

auth_curl() {
  curl -sf -u "$ZO_ROOT_USER_EMAIL:$ZO_ROOT_USER_PASSWORD" "$@"
}

schema_matches_desired() {
  echo "$1" | jq -e --slurpfile d "$DESIRED_SCHEMA_FILE" '
    (.settings.defined_schema_fields // []) as $cur |
    [$d[0].schema[].name] as $want |
    (($want | length) == ($cur | length)) and
    ($want | all(. as $n | $cur | index($n) != null))
  ' >/dev/null
}

print_schema_counts() {
  _label="$1"
  _json="$2"
  _defined="$(echo "$_json" | jq '(.settings.defined_schema_fields // []) | length')"
  _uds="$(echo "$_json" | jq '(.uds_schema // []) | length')"
  log "${_label}: defined_schema_fields=${_defined}, uds_schema=${_uds} (expected ${expected_count})"
}

log "waiting for ${O2_HOST}/healthz (max ${HEALTH_WAIT_SECONDS}s)..."
elapsed=0
until auth_curl "${O2_HOST}/healthz" >/dev/null 2>&1; do
  if [ "$elapsed" -ge "$HEALTH_WAIT_SECONDS" ]; then
    die "OpenObserve not ready after ${HEALTH_WAIT_SECONDS}s"
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
log "openobserve is healthy"

log "fetching current schema"
current="$(auth_curl "${O2_HOST}/api/default/streams/paragon/schema?type=logs")"
print_schema_counts "before apply" "$current"

if schema_matches_desired "$current"; then
  log "UDS already matches desired schema; skipping PUT"
  log "done (no changes)"
  exit 0
fi

log "schema drift detected; building PUT payload"
# jq: compute add/remove vs desired list (same semantics as o2-apply-uds.ts).
payload="$(echo "$current" | jq -c --slurpfile d "$DESIRED_SCHEMA_FILE" '
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
')"

add_names="$(echo "$payload" | jq '.defined_schema_fields.add | length')"
remove_names="$(echo "$payload" | jq '.defined_schema_fields.remove | length')"
remove_fields="$(echo "$payload" | jq '.fields.remove | length')"
log "PUT payload: add ${add_names} defined_schema_fields, remove ${remove_names} names, remove ${remove_fields} field objects"

log "applying UDS via PUT ${O2_HOST}/api/default/streams/paragon/settings"
auth_curl \
  -X PUT \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "${O2_HOST}/api/default/streams/paragon/settings"

log "verifying schema after PUT"
updated="$(auth_curl "${O2_HOST}/api/default/streams/paragon/schema?type=logs")"
print_schema_counts "after apply" "$updated"

defined_count="$(echo "$updated" | jq '(.settings.defined_schema_fields // []) | length')"
uds_count="$(echo "$updated" | jq '(.uds_schema // []) | length')"

if [ "$defined_count" -ne "$expected_count" ]; then
  die "post-PUT defined_schema_fields count ${defined_count} != expected ${expected_count}"
fi

if [ "$uds_count" -ne "$expected_count" ]; then
  die "post-PUT uds_schema count ${uds_count} != expected ${expected_count}"
fi

if ! schema_matches_desired "$updated"; then
  die "post-PUT schema field names do not match desired list"
fi

log "UDS apply succeeded: ${defined_count} defined_schema_fields, ${uds_count} uds_schema fields"
log "done"
