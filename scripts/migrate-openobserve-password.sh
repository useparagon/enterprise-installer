#!/usr/bin/env bash
# migrate-openobserve-password.sh
#
# One-time manual step AFTER terraform apply on existing OpenObserve clusters.
#
# Terraform writes the new password to openobserve-credentials (ESO). OpenObserve
# still has the old password in its PVC until this script runs.
#
# Two access modes (pick one):
#
#   Hoop (hoop login first):
#     ./scripts/migrate-openobserve-password.sh \
#       --hoop paragon-eu-openobserve \
#       --old-password 'legacy-from-1password'
#
#   Manual port-forward (run this script where you have cluster access):
#     kubectl port-forward -n paragon svc/openobserve 5080:5080
#     ./scripts/migrate-openobserve-password.sh \
#       --o2-host http://127.0.0.1:5080 \
#       --old-password 'legacy-from-1password'
#
set -euo pipefail

LOG_PREFIX="[o2-password-migrate]"

NAMESPACE="${NAMESPACE:-paragon}"
ORG="${ORG:-default}"
SECRET_NAME="${SECRET_NAME:-openobserve-credentials}"
O2_PORT="${O2_PORT:-5080}"

HOOP_CONN=""
HOOP_K8S_CONN=""
O2_HOST=""
OLD_PASSWORD=""
EMAIL_OVERRIDE=""
DRY_RUN=false
USE_HOOP=false

HOOP_PID=""

usage() {
  cat <<'EOF'
migrate-openobserve-password.sh

Syncs OpenObserve (PVC) with the new password already in openobserve-credentials
after terraform apply.

  1. terraform apply
  2. Run this script (Hoop OR manual port-forward)

Hoop (--hoop-k8s reads secret, --hoop proxies OpenObserve API in background):
  ./scripts/migrate-openobserve-password.sh \
    --hoop-k8s paragon-eu-k8s-admin \
    --hoop paragon-eu-openobserve \
    --old-password 'legacy-from-1password'

  # --hoop-k8s is optional when --hoop ends with -openobserve (derives {prefix}-k8s-admin)

Manual port-forward (you run kubectl/bastion forward, pass the local URL):
  kubectl port-forward -n paragon svc/openobserve 5080:5080
  ./scripts/migrate-openobserve-password.sh \
    --o2-host http://127.0.0.1:5080 \
    --old-password 'legacy-from-1password'

Options:
  --hoop NAME            Hoop TCP connection to OpenObserve (e.g. paragon-eu-openobserve). Mutually exclusive with --o2-host.
  --hoop-k8s NAME        Hoop k8s-admin connection to read the secret (e.g. paragon-eu-k8s-admin). Default: {prefix}-k8s-admin from --hoop.
  --o2-host URL          OpenObserve base URL from your local port-forward (e.g. http://127.0.0.1:5080).
  --old-password PASS    Current OpenObserve PVC password. Required unless secret password already works.
  --email EMAIL          OpenObserve root email (PVC). Default: ZO_ROOT_USER_EMAIL from --secret.
  --namespace NAME       Kubernetes namespace (default: paragon)
  --org NAME             OpenObserve organization (default: default)
  --secret NAME          Secret with Terraform password (default: openobserve-credentials)
  --port PORT            Local port for hoop connect proxy only (default: 5080)
  --dry-run              Print actions without calling the API
  -h, --help             Show this help
EOF
}

log() { echo "${LOG_PREFIX} $*" >&2; }
die() { echo "${LOG_PREFIX} error: $*" >&2; exit 1; }

print_vault_reminder() {
  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  printf '\033[1;33m\033[1m%s\033[0m\n' "⚠️  UPDATE 1PASSWORD / VAULT" >&2
  echo "" >&2
  echo "  Save the new OpenObserve credentials in the customer vault." >&2
  echo "  Email:    ${EMAIL}" >&2
  echo "  Password: current value in ${SECRET_NAME} (cluster / Terraform)" >&2
  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "" >&2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

urlencode() {
  jq -nr --arg v "$1" '$v|@uri'
}

normalize_o2_host() {
  local url="$1"
  case "$url" in
    http://*|https://*) ;;
    *) url="http://${url}" ;;
  esac
  url="${url%/}"
  printf '%s' "$url"
}

default_hoop_k8s_conn() {
  local o2_conn="$1"
  if [[ "$o2_conn" == *-openobserve ]]; then
    echo "${o2_conn%-openobserve}-k8s-admin"
    return
  fi
  die "pass --hoop-k8s explicitly, or use an --hoop connection ending in -openobserve"
}

cleanup() {
  if [ -n "$HOOP_PID" ] && kill -0 "$HOOP_PID" 2>/dev/null; then
    log "stopping hoop connect (pid ${HOOP_PID})"
    kill "$HOOP_PID" 2>/dev/null || true
    wait "$HOOP_PID" 2>/dev/null || true
  fi
}

start_hoop_proxy() {
  O2_HOST="$(normalize_o2_host "127.0.0.1:${O2_PORT}")"
  log "starting hoop connect ${HOOP_CONN} -> ${O2_HOST} (background)"
  hoop connect "$HOOP_CONN" -p "$O2_PORT" -s -d 15m >/dev/null 2>&1 &
  HOOP_PID=$!
  trap cleanup EXIT INT TERM

  local i=0
  while [ "$i" -lt 90 ]; do
    if curl -sf --connect-timeout 2 --max-time 3 "${O2_HOST}/healthz" >/dev/null 2>&1; then
      log "OpenObserve reachable via hoop proxy"
      return
    fi
    if ! kill -0 "$HOOP_PID" 2>/dev/null; then
      die "hoop connect exited before OpenObserve became reachable"
    fi
    sleep 1
    i=$((i + 1))
  done
  die "timeout waiting for OpenObserve on ${O2_HOST}"
}

wait_for_o2_host() {
  log "checking OpenObserve at ${O2_HOST}"
  curl -sf --connect-timeout 10 --max-time 30 "${O2_HOST}/healthz" >/dev/null \
    || die "OpenObserve not reachable at ${O2_HOST}/healthz (is port-forward running?)"
}

secret_field_kubectl() {
  local key="$1"
  local b64
  b64="$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o "jsonpath={.data.${key}}")"
  [ -n "$b64" ] || die "failed to read ${key} from secret ${SECRET_NAME}"
  printf '%s' "$b64" | base64 -d
}

secret_field_hoop() {
  local key="$1"
  local b64 raw err
  log "reading ${key} via hoop connect ${HOOP_K8S_CONN} (secret ${SECRET_NAME})"
  err="$(mktemp)"
  raw="$(hoop connect "$HOOP_K8S_CONN" -s -- \
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" \
    -o "jsonpath={.data.${key}}" 2>"$err" || true)"
  # kubectl jsonpath is a single base64 line; ignore any hoop banner noise on stdout
  b64="$(printf '%s\n' "$raw" | grep -E '^[A-Za-z0-9+/=]+$' | tail -1 | tr -d '[:space:]')"
  if [ -z "$b64" ]; then
    log "hoop/kubectl stderr: $(tr '\n' ' ' <"$err" | tr -d '\r')"
    log "hoop stdout (truncated): $(printf '%s' "$raw" | head -c 200)"
    rm -f "$err"
    die "failed to read ${key} from secret ${SECRET_NAME} (hoop connect ${HOOP_K8S_CONN})"
  fi
  rm -f "$err"
  printf '%s' "$b64" | base64 -d
}

# Basic auth via header — curl -u truncates passwords that contain '#' (and is
# fragile with other specials). Always base64 the full user:pass pair.
basic_auth_header() {
  local user="$1" pass="$2"
  local token
  token="$(printf '%s:%s' "$user" "$pass" | base64 | tr -d '\n')"
  printf 'Authorization: Basic %s' "$token"
}

auth_status() {
  local user="$1" pass="$2"
  curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 \
    -H "$(basic_auth_header "$user" "$pass")" \
    "${O2_HOST}/api/${ORG}/streams?type=logs"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hoop) HOOP_CONN="$2"; USE_HOOP=true; shift 2 ;;
    --hoop-k8s) HOOP_K8S_CONN="$2"; shift 2 ;;
    --connection) HOOP_CONN="$2"; USE_HOOP=true; shift 2 ;; # alias
    --o2-host|--o2-url|--openobserve-host) O2_HOST="$(normalize_o2_host "$2")"; shift 2 ;;
    --old-password) OLD_PASSWORD="$2"; shift 2 ;;
    --email|--user|--username) EMAIL_OVERRIDE="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --secret) SECRET_NAME="$2"; shift 2 ;;
    --port) O2_PORT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (use --help)" ;;
  esac
done

need_cmd curl
need_cmd jq
need_cmd base64

if [ "$USE_HOOP" = true ] && [ -n "$O2_HOST" ]; then
  die "use either --hoop or --o2-host, not both"
fi
if [ "$USE_HOOP" = false ] && [ -z "$O2_HOST" ]; then
  die "pass --hoop <connection> or --o2-host <url> (see --help)"
fi

if [ "$USE_HOOP" = true ]; then
  need_cmd hoop
  [ -n "$HOOP_CONN" ] || die "--hoop requires a connection name"
  [ -n "$HOOP_K8S_CONN" ] || HOOP_K8S_CONN="$(default_hoop_k8s_conn "$HOOP_CONN")"
  log "mode=hoop o2=${HOOP_CONN} k8s=${HOOP_K8S_CONN}"
  EMAIL="$(secret_field_hoop ZO_ROOT_USER_EMAIL | tr -d '[:space:]')"
  NEW_PASSWORD="$(secret_field_hoop ZO_ROOT_USER_PASSWORD | tr -d '[:space:]')"
  start_hoop_proxy
else
  need_cmd kubectl
  log "mode=manual o2=${O2_HOST} namespace=${NAMESPACE}"
  wait_for_o2_host
  EMAIL="$(secret_field_kubectl ZO_ROOT_USER_EMAIL)"
  NEW_PASSWORD="$(secret_field_kubectl ZO_ROOT_USER_PASSWORD)"
fi

[ -n "$EMAIL" ] || die "ZO_ROOT_USER_EMAIL empty in secret"
[ -n "$NEW_PASSWORD" ] || die "ZO_ROOT_USER_PASSWORD empty in secret"
if [ "${#NEW_PASSWORD}" -lt 8 ] || [ "${#NEW_PASSWORD}" -gt 128 ]; then
  die "secret password length ${#NEW_PASSWORD} out of range (8–128); check hoop secret read output"
fi

SECRET_EMAIL="$EMAIL"
if [ -n "$EMAIL_OVERRIDE" ]; then
  EMAIL="$EMAIL_OVERRIDE"
  log "using --email ${EMAIL} (secret has ${SECRET_EMAIL})"
fi

log "email=${EMAIL}"
log "new password from secret (${#NEW_PASSWORD} chars)"

# Already synced: secret password works against OO PVC — nothing to do.
log "checking if secret password already authenticates"
new_status="$(auth_status "$EMAIL" "$NEW_PASSWORD")"
if [ "$new_status" = "200" ]; then
  log "already in sync — OpenObserve accepts password from ${SECRET_NAME}"
  print_vault_reminder
  exit 0
fi
log "secret password not accepted yet (HTTP ${new_status}) — migration needed"

[ -n "$OLD_PASSWORD" ] || die "--old-password is required (PVC still has the legacy password)"

if [ "$OLD_PASSWORD" = "$NEW_PASSWORD" ]; then
  die "secret password equals --old-password; OpenObserve rejected both — check --old-password vs ${SECRET_NAME}"
fi

log "verifying --old-password against OpenObserve API"
old_status="$(auth_status "$EMAIL" "$OLD_PASSWORD")"
if [ "$old_status" != "200" ]; then
  die "--old-password rejected (HTTP ${old_status}). Confirm the value that works against OO."
fi
log "old password accepted"

EMAIL_ENC="$(urlencode "$EMAIL")"
PAYLOAD="$(jq -nc \
  --arg old "$OLD_PASSWORD" \
  --arg new "$NEW_PASSWORD" \
  '{change_password: true, old_password: $old, new_password: $new}')"

log "changing OpenObserve password via PUT ${O2_HOST}/api/${ORG}/users/${EMAIL}"

if [ "$DRY_RUN" = true ]; then
  log "dry-run: would call user update API (old -> secret password)"
  exit 0
fi

http_code="$(curl -s -o /tmp/o2-migrate-response.json -w '%{http_code}' \
  --connect-timeout 10 --max-time 120 \
  -H "$(basic_auth_header "$EMAIL" "$OLD_PASSWORD")" \
  -X PUT \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" \
  "${O2_HOST}/api/${ORG}/users/${EMAIL_ENC}")"

if [ "$http_code" != "200" ]; then
  echo "${LOG_PREFIX} API response (${http_code}):" >&2
  cat /tmp/o2-migrate-response.json >&2 || true
  die "OpenObserve password change failed (HTTP ${http_code})"
fi

log "password updated in OpenObserve"

new_status="$(auth_status "$EMAIL" "$NEW_PASSWORD")"
if [ "$new_status" != "200" ]; then
  die "secret password rejected after API change (HTTP ${new_status})"
fi

log "done — OpenObserve matches ${SECRET_NAME}"
print_vault_reminder
