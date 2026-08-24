#!/usr/bin/env bash
# failover-datastores.sh
#
# Repoint a running Paragon deployment at different Postgres / Redis endpoints
# without running terraform. Intended for deployments where the data stores are
# customer-managed (infra `postgres_enabled = false` / `redis_enabled = false`)
# and failover is driven outside this repo.
#
# What it does, in order:
#   1. Rewrites the Key Vault secrets that hold connection info (`postgres`,
#      `redis`, `redis-managed`) so the next terraform apply keeps the new
#      endpoints instead of reverting to the old ones.
#   2. Rewrites the runtime secrets the cluster actually reads (`env`, and
#      `managed-sync` when managed sync is deployed).
#   3. Forces External Secrets to resync immediately instead of waiting for its
#      5 minute refresh interval.
#   4. Restarts the workloads that consume those secrets, since secretKeyRef
#      env vars are only injected at container start.
#
# Example (host swap, credentials unchanged):
#   ./azure/scripts/failover-datastores.sh \
#     --vault paragon-acme-a1b2c3 \
#     --replace primary.postgres.database.azure.com=standby.postgres.database.azure.com \
#     --replace primary.redis.cache.windows.net=standby.redis.cache.windows.net
#
# Always rehearse with --dry-run first; it prints every key that would change.
set -euo pipefail

LOG_PREFIX="[failover]"

VAULT=""
NAMESPACE="${NAMESPACE:-paragon}"
RUNTIME_SECRETS=("env" "managed-sync")
CONNECTION_SECRETS=("postgres" "redis" "redis-managed")
SKIP_CONNECTION_SECRETS=false
RESTART_MODE="auto"
SYNC_TIMEOUT=180
DRY_RUN=false

REPLACEMENTS_JSON="[]"
OVERRIDES_JSON="{}"

# Runtime secret name -> ExternalSecret / Kubernetes secret name.
external_secret_for() {
  case "$1" in
    env) echo "paragon-secrets" ;;
    managed-sync) echo "paragon-managed-sync-secrets" ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<'EOF'
failover-datastores.sh

Repoints Paragon at new Postgres / Redis endpoints by rewriting Key Vault
secrets and rolling the pods that read them. No terraform run required.

Required:
  --vault NAME            Paragon Key Vault name (infra workspace output; the
                          workspace name truncated to 24 characters).

Changes to apply (at least one):
  --replace OLD=NEW       Literal string replacement applied to every value in
                          every secret this script touches. Use it for hostname
                          swaps; it also rewrites hosts embedded in Redis URLs.
                          Repeatable.
  --set KEY=VALUE         Exact value for one env key (for example
                          CACHE_REDIS_URL). Applied to the runtime secrets only.
                          Repeatable.

Options:
  --namespace NAME        Kubernetes namespace (default: paragon)
  --secrets LIST          Comma separated runtime secrets to rewrite
                          (default: env,managed-sync). Missing ones are skipped.
  --skip-connection-secrets
                          Do not touch postgres / redis / redis-managed. The
                          next terraform apply will then revert the change.
  --restart MODE          auto (workloads that reference the changed secrets),
                          all (everything in the namespace), or none.
                          Default: auto
  --timeout SECONDS       How long to wait for External Secrets to publish the
                          new values (default: 180)
  --dry-run               Print the keys that would change and exit
  -h, --help              Show this help

Notes:
  * Passwords inside Redis URLs are URL encoded, so --replace on a raw password
    will not match. Pass the rebuilt URL with --set CACHE_REDIS_URL=... instead.
  * Ports and the TLS / cluster flags (for example CERBERUS_POSTGRES_PORT,
    CACHE_REDIS_TLS_ENABLED) are plain pod env values rather than secrets, so
    changing those still requires a terraform apply of the paragon workspace.
EOF
}

log() { echo "${LOG_PREFIX} $*" >&2; }
die() { echo "${LOG_PREFIX} error: $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --vault|--key-vault) VAULT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --replace)
      case "$2" in
        *=*) ;;
        *) die "--replace expects OLD=NEW, got: $2" ;;
      esac
      REPLACEMENTS_JSON="$(jq -c --arg from "${2%%=*}" --arg to "${2#*=}" \
        '. + [{from: $from, to: $to}]' <<<"$REPLACEMENTS_JSON")"
      shift 2 ;;
    --set)
      case "$2" in
        *=*) ;;
        *) die "--set expects KEY=VALUE, got: $2" ;;
      esac
      OVERRIDES_JSON="$(jq -c --arg key "${2%%=*}" --arg value "${2#*=}" \
        '. + {($key): $value}' <<<"$OVERRIDES_JSON")"
      shift 2 ;;
    --secrets) IFS=',' read -r -a RUNTIME_SECRETS <<<"$2"; shift 2 ;;
    --skip-connection-secrets) SKIP_CONNECTION_SECRETS=true; shift ;;
    --restart) RESTART_MODE="$2"; shift 2 ;;
    --timeout) SYNC_TIMEOUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (use --help)" ;;
  esac
done

need_cmd az
need_cmd jq
need_cmd base64
[ "$RESTART_MODE" = "none" ] || need_cmd kubectl

[ -n "$VAULT" ] || die "--vault is required (see --help)"
case "$RESTART_MODE" in
  auto|all|none) ;;
  *) die "--restart must be auto, all, or none" ;;
esac
if [ "$(jq 'length' <<<"$REPLACEMENTS_JSON")" -eq 0 ] && [ "$(jq 'length' <<<"$OVERRIDES_JSON")" -eq 0 ]; then
  die "pass at least one --replace or --set (see --help)"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Secret names that were rewritten, so we know which ExternalSecrets to resync.
CHANGED_RUNTIME_SECRETS=()
# Key names changed in each runtime secret, used to confirm the cluster caught up.
declare -A CHANGED_KEYS

read_secret() {
  local name="$1"
  az keyvault secret show --vault-name "$VAULT" --name "$name" -o json 2>/dev/null \
    | jq -r '.value'
}

# Literal (non-regex) replacement on every string in the document, plus exact
# key overrides for the flat runtime secrets.
transform_secret() {
  local payload="$1" allow_overrides="$2"
  jq -c \
    --argjson replacements "$REPLACEMENTS_JSON" \
    --argjson overrides "$(if [ "$allow_overrides" = "true" ]; then echo "$OVERRIDES_JSON"; else echo "{}"; fi)" '
      def substitute($text):
        reduce $replacements[] as $r ($text; split($r.from) | join($r.to));
      walk(if type == "string" then substitute(.) else . end)
      | if (type == "object" and ($overrides | length) > 0) then . + $overrides else . end
    ' <<<"$payload"
}

changed_keys_between() {
  local before="$1" after="$2"
  jq -r -n --argjson before "$before" --argjson after "$after" '
    if ($after | type) != "object" then empty
    else
      ($before + $after | keys_unsorted)[]
      | select(($before[.] // null) != ($after[.] // null))
    end
  ' 2>/dev/null || true
}

write_secret() {
  local name="$1" payload="$2"
  local file="${TMP_DIR}/${name}.json"
  printf '%s' "$payload" >"$file"
  az keyvault secret set --vault-name "$VAULT" --name "$name" --file "$file" -o none
}

process_secret() {
  local name="$1" allow_overrides="$2"

  local current
  current="$(read_secret "$name" || true)"
  if [ -z "$current" ] || [ "$current" = "null" ]; then
    log "skip ${name}: not present in ${VAULT}"
    return 0
  fi
  if ! jq -e . >/dev/null 2>&1 <<<"$current"; then
    die "${name} in ${VAULT} is not valid JSON"
  fi

  local updated
  updated="$(transform_secret "$current" "$allow_overrides")"
  if [ "$(jq -S -c . <<<"$current")" = "$(jq -S -c . <<<"$updated")" ]; then
    log "skip ${name}: no matching values"
    return 0
  fi

  local keys
  keys="$(changed_keys_between "$(jq -c . <<<"$current")" "$updated")"
  if [ -n "$keys" ]; then
    log "${name}: $(tr '\n' ' ' <<<"$keys")"
  else
    log "${name}: nested values changed"
  fi

  if [ "$DRY_RUN" = true ]; then
    return 0
  fi

  write_secret "$name" "$updated"
  log "${name}: new version written to ${VAULT}"

  if external_secret_for "$name" >/dev/null 2>&1; then
    CHANGED_RUNTIME_SECRETS+=("$name")
    CHANGED_KEYS["$name"]="$keys"
  fi
}

force_sync() {
  local secret_name="$1"
  local external_secret
  external_secret="$(external_secret_for "$secret_name")"
  log "forcing External Secrets resync of ${external_secret}"
  kubectl annotate externalsecret "$external_secret" -n "$NAMESPACE" \
    "force-sync=$(date +%s)" --overwrite >/dev/null
}

wait_for_sync() {
  local secret_name="$1"
  local external_secret keys deadline
  external_secret="$(external_secret_for "$secret_name")"
  keys="${CHANGED_KEYS[$secret_name]}"
  [ -n "$keys" ] || return 0

  local expected_payload
  expected_payload="$(cat "${TMP_DIR}/${secret_name}.json")"
  deadline=$(( $(date +%s) + SYNC_TIMEOUT ))

  while [ "$(date +%s)" -lt "$deadline" ]; do
    local synced=true key expected actual
    while IFS= read -r key; do
      [ -n "$key" ] || continue
      expected="$(jq -r --arg k "$key" '.[$k] // ""' <<<"$expected_payload")"
      actual="$(kubectl get secret "$external_secret" -n "$NAMESPACE" \
        -o "jsonpath={.data.${key}}" 2>/dev/null | base64 -d 2>/dev/null || true)"
      if [ "$expected" != "$actual" ]; then
        synced=false
        break
      fi
    done <<<"$keys"

    if [ "$synced" = true ]; then
      log "${external_secret} now holds the new values"
      return 0
    fi
    sleep 3
  done

  die "timed out after ${SYNC_TIMEOUT}s waiting for ${external_secret}; check: kubectl describe externalsecret ${external_secret} -n ${NAMESPACE}"
}

workloads_using_secrets() {
  local names_json
  names_json="$(printf '%s\n' "${CHANGED_RUNTIME_SECRETS[@]}" \
    | while IFS= read -r n; do external_secret_for "$n"; done \
    | jq -R . | jq -s -c .)"

  kubectl get deployments,statefulsets -n "$NAMESPACE" -o json \
    | jq -r --argjson secrets "$names_json" '
      .items[]
      | select(
          [ .spec.template.spec.containers[]?, .spec.template.spec.initContainers[]?
            | (.envFrom[]?.secretRef.name // empty),
              (.env[]?.valueFrom.secretKeyRef.name // empty)
          ] | any(. as $ref | $secrets | index($ref) != null)
        )
      | "\(.kind|ascii_downcase)/\(.metadata.name)"
    '
}

restart_workloads() {
  local targets
  case "$RESTART_MODE" in
    none)
      log "skipping restart (--restart none); pods keep the old values until they restart"
      return 0 ;;
    all)
      targets="$(kubectl get deployments,statefulsets -n "$NAMESPACE" -o json \
        | jq -r '.items[] | "\(.kind|ascii_downcase)/\(.metadata.name)"')" ;;
    auto)
      targets="$(workloads_using_secrets)" ;;
  esac

  if [ -z "$targets" ]; then
    log "no workloads matched for restart"
    return 0
  fi

  log "restarting: $(tr '\n' ' ' <<<"$targets")"
  # shellcheck disable=SC2086
  kubectl rollout restart -n "$NAMESPACE" $(tr '\n' ' ' <<<"$targets") >/dev/null
}

log "vault=${VAULT} namespace=${NAMESPACE} restart=${RESTART_MODE} dry-run=${DRY_RUN}"

if [ "$SKIP_CONNECTION_SECRETS" = false ]; then
  for secret in "${CONNECTION_SECRETS[@]}"; do
    process_secret "$secret" false
  done
else
  log "skipping postgres / redis / redis-managed; the next terraform apply will revert this failover"
fi

for secret in "${RUNTIME_SECRETS[@]}"; do
  external_secret_for "$secret" >/dev/null 2>&1 \
    || die "unsupported runtime secret: ${secret} (expected env or managed-sync)"
  process_secret "$secret" true
done

if [ "$DRY_RUN" = true ]; then
  log "dry run complete; no secrets were written"
  exit 0
fi

if [ "${#CHANGED_RUNTIME_SECRETS[@]}" -eq 0 ]; then
  log "no runtime secret changed; nothing to roll out"
  exit 0
fi

for secret in "${CHANGED_RUNTIME_SECRETS[@]}"; do
  force_sync "$secret"
done

for secret in "${CHANGED_RUNTIME_SECRETS[@]}"; do
  wait_for_sync "$secret"
done

restart_workloads

if [ "$SKIP_CONNECTION_SECRETS" = false ] && [ "$(jq 'length' <<<"$OVERRIDES_JSON")" -gt 0 ]; then
  log "reminder: --set only edits runtime secrets. Confirm postgres / redis in ${VAULT} describe the same endpoints, or the next terraform apply will rebuild those keys from them."
fi

log "done; watch progress with: kubectl get pods -n ${NAMESPACE} -w"
