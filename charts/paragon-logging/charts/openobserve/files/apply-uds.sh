#!/bin/sh
# Apply OpenObserve user-defined schema for the paragon logs stream (idempotent).
# PARA-20444 — same semantics as o2-apply-uds.ts (GET, compare, single PUT).
set -eu

DESIRED_SCHEMA="${DESIRED_SCHEMA:-/schema/openobserve-uds-schema.json}"
O2_HOST="${O2_HOST:-http://openobserve:5080}"
O2_USER="${O2_USER:-${ZO_ROOT_USER_EMAIL:-}}"
O2_PASS="${O2_PASS:-${ZO_ROOT_USER_PASSWORD:-}}"
HEALTH_WAIT_SECONDS="${HEALTH_WAIT_SECONDS:-120}"

if [ -z "$O2_USER" ] || [ -z "$O2_PASS" ]; then
  echo "error: O2_USER/O2_PASS (or ZO_ROOT_USER_EMAIL/ZO_ROOT_USER_PASSWORD) required" >&2
  exit 1
fi

if [ ! -f "$DESIRED_SCHEMA" ]; then
  echo "error: desired schema not found: $DESIRED_SCHEMA" >&2
  exit 1
fi

# Strip trailing slash from O2_HOST
O2_HOST="${O2_HOST%/}"

auth_curl() {
  curl -sf -u "$O2_USER:$O2_PASS" "$@"
}

echo "Waiting for OpenObserve at ${O2_HOST}/healthz (max ${HEALTH_WAIT_SECONDS}s)..."
elapsed=0
until auth_curl "${O2_HOST}/healthz" >/dev/null 2>&1; do
  if [ "$elapsed" -ge "$HEALTH_WAIT_SECONDS" ]; then
    echo "error: OpenObserve not ready after ${HEALTH_WAIT_SECONDS}s" >&2
    exit 1
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

echo "Fetching current schema"
current="$(auth_curl "${O2_HOST}/api/default/streams/paragon/schema?type=logs")"

if jq -e --slurpfile d "$DESIRED_SCHEMA" '
  (.settings.defined_schema_fields // []) as $cur |
  [$d[0].schema[].name] as $want |
  (($want | length) == ($cur | length)) and
  ($want | all(. as $n | $cur | index($n) != null))
' <<<"$current" >/dev/null; then
  echo "UDS already applied; skipping PUT"
  exit 0
fi

echo "Building UDS payload"
payload="$(jq -c --slurpfile d "$DESIRED_SCHEMA" '
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
' <<<"$current")"

echo "Applying UDS schema"
auth_curl \
  -X PUT \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "${O2_HOST}/api/default/streams/paragon/settings"

echo "Verifying updated schema"
updated="$(auth_curl "${O2_HOST}/api/default/streams/paragon/schema?type=logs")"
uds_count="$(jq '(.uds_schema // []) | length' <<<"$updated")"
defined_count="$(jq '(.settings.defined_schema_fields // []) | length' <<<"$updated")"
echo "UDS applied: ${uds_count} uds_schema fields, ${defined_count} defined_schema_fields"
