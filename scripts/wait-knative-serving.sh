#!/bin/sh
# Poll KnativeServing Ready. Used by the paragon helm module in place of a
# fixed sleep: the operator installs Serving only after the CR is applied.
set -eu

host="${KNATIVE_API_HOST:?KNATIVE_API_HOST is required}"
wait_seconds="${KNATIVE_WAIT_SECONDS:-1200}"
namespace="${KNATIVE_NAMESPACE:-knative-serving}"
name="${KNATIVE_NAME:-knative-serving}"
host="${host%/}"

deadline=$(($(date +%s) + wait_seconds))
ca_file=""
cert_file=""
key_file=""
body_file="$(mktemp)"

cleanup() {
  [ -z "$ca_file" ] || rm -f "$ca_file"
  [ -z "$cert_file" ] || rm -f "$cert_file"
  [ -z "$key_file" ] || rm -f "$key_file"
  rm -f "$body_file"
}
trap cleanup EXIT

umask 077
if [ -n "${KNATIVE_CA_PEM:-}" ]; then
  ca_file="$(mktemp)"
  printf '%s\n' "$KNATIVE_CA_PEM" >"$ca_file"
fi
if [ -n "${KNATIVE_CLIENT_CERT:-}" ]; then
  cert_file="$(mktemp)"
  key_file="$(mktemp)"
  printf '%s\n' "$KNATIVE_CLIENT_CERT" >"$cert_file"
  printf '%s\n' "$KNATIVE_CLIENT_KEY" >"$key_file"
fi

url="${host}/apis/operator.knative.dev/v1beta1/namespaces/${namespace}/knativeservings/${name}"

while true; do
  token="${KNATIVE_TOKEN:-}"
  if [ -n "${KNATIVE_AWS_CLUSTER:-}" ]; then
    set -- aws eks get-token \
      --cluster-name "$KNATIVE_AWS_CLUSTER" \
      --region "${KNATIVE_AWS_REGION:?KNATIVE_AWS_REGION is required}" \
      --query status.token \
      --output text
    if [ -n "${KNATIVE_AWS_ROLE_ARN:-}" ]; then
      set -- "$@" --role-arn "$KNATIVE_AWS_ROLE_ARN"
    fi
    token="$("$@")" || token=""
  fi

  set -- curl -sS -o "$body_file" -w "%{http_code}"
  if [ -n "$ca_file" ]; then
    set -- "$@" --cacert "$ca_file"
  fi
  if [ -n "$token" ]; then
    set -- "$@" -H "Authorization: Bearer ${token}"
  fi
  if [ -n "$cert_file" ]; then
    set -- "$@" --cert "$cert_file" --key "$key_file"
  fi
  if [ -n "${KNATIVE_USERNAME:-}" ]; then
    set -- "$@" --user "${KNATIVE_USERNAME}:${KNATIVE_PASSWORD:-}"
  fi
  set -- "$@" "$url"

  http_code="000"
  http_code="$("$@")" || http_code="000"

  ready="$(
    python3 - "$body_file" <<'PY' || true
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except (OSError, json.JSONDecodeError):
    sys.exit(0)
for condition in (data.get("status") or {}).get("conditions") or []:
    if condition.get("type") == "Ready":
        print(condition.get("status") or "")
        break
PY
  )"

  if [ "$http_code" = "200" ] && [ "$ready" = "True" ]; then
    exit 0
  fi

  now="$(date +%s)"
  if [ "$now" -ge "$deadline" ]; then
    echo "KnativeServing ${namespace}/${name} was not Ready within ${wait_seconds}s (http=${http_code} ready=${ready:-missing})" >&2
    python3 - "$body_file" <<'PY' || true
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
except (OSError, json.JSONDecodeError):
    sys.exit(0)
for condition in (data.get("status") or {}).get("conditions") or []:
    print(
        "{type}={status} reason={reason} message={message}".format(
            type=condition.get("type"),
            status=condition.get("status"),
            reason=condition.get("reason") or "",
            message=condition.get("message") or "",
        ),
        file=sys.stderr,
    )
PY
    exit 1
  fi

  sleep 10
done
