#!/bin/sh
# Regressions for the physical Valkey catalog. Uses actual Terraform locals,
# not a reimplementation of their conditions.
set -eu
cd "$(dirname "$0")/.."

assert_topology() {
  label="$1"
  expect="$2"
  shift 2
  result="$(printf '%s\n' 'jsonencode({physical=sort(keys(local.valkey_instances)),roles=local.valkey_role_instances})' |
    terraform console -state=/tmp/valkey-topology-empty.test.tfstate "$@")"
  if ! printf '%s\n' "$result" | jq -r . | jq -e "$expect" >/dev/null; then
    printf 'FAIL: %s\n' "$label" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$label"
}

assert_topology 'shared redis/cache with Managed Sync and Agent OS' \
  '.physical == ["agent_os","cache"] and .roles.cache == "cache" and .roles.queue == "cache" and .roles.system == "cache" and .roles.workflow == "cache" and .roles.managed_sync == "cache" and .roles.agent_os == "agent_os"' \
  -var=valkey_shared=true -var=elasticache_multiple_instances=false \
  -var=managed_sync_enabled=true -var=agent_os_enabled=true

assert_topology 'separate cache/queue/system/managed_sync plus Agent OS' \
  '.physical == ["agent_os","cache","managed_sync","queue","system"] and .roles.cache == "cache" and .roles.queue == "queue" and .roles.system == "system" and .roles.workflow == "cache" and .roles.managed_sync == "managed_sync" and .roles.agent_os == "agent_os"' \
  -var=valkey_shared=false -var=elasticache_multiple_instances=true \
  -var=managed_sync_enabled=true -var=agent_os_enabled=true

assert_topology 'no Managed Sync or Agent OS' \
  '.physical == ["cache","queue","system"]' \
  -var=valkey_shared=false -var=elasticache_multiple_instances=true \
  -var=managed_sync_enabled=false -var=agent_os_enabled=false

assert_topology 'single Valkey without Managed Sync' \
  '.physical == ["cache"] and .roles.managed_sync == "cache" and .roles.agent_os == "agent_os"' \
  -var=valkey_shared=true -var=elasticache_multiple_instances=false \
  -var=managed_sync_enabled=false -var=agent_os_enabled=false
