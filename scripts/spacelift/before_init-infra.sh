#!/usr/bin/env bash
# Spacelift before_init for <cloud>/workspaces/infra.
#
# Usage (from cloud entrypoint): before_init-infra.sh <aws|azure|gcp>
# Or set SPACELIFT_CLOUD.
#
# Required env:
#   SPACELIFT_STATE_BUCKET
#   SPACELIFT_STATE_KEY
#   SPACELIFT_STATE_REGION
#   SPACELIFT_STATE_DYNAMODB_TABLE
# Optional:
#   SPACELIFT_STATE_ROLE_ARN
set -euo pipefail

REPO_ROOT="$(cd "$(pwd)/../../.." && pwd)"
if [[ ! -f "${REPO_ROOT}/prepare.sh" ]]; then
  if [[ -f "./prepare.sh" ]]; then
    REPO_ROOT="$(pwd)"
  else
    echo "ERROR: cannot locate enterprise-installer repo root from $(pwd)" >&2
    exit 1
  fi
fi

cd "${REPO_ROOT}"

CLOUD="${1:-${SPACELIFT_CLOUD:-aws}}"
case "${CLOUD}" in
  aws|azure|gcp) ;;
  *)
    echo "ERROR: invalid cloud '${CLOUD}' (expected aws|azure|gcp)" >&2
    exit 1
    ;;
esac

: "${SPACELIFT_STATE_BUCKET:?SPACELIFT_STATE_BUCKET is required}"
: "${SPACELIFT_STATE_KEY:?SPACELIFT_STATE_KEY is required}"
: "${SPACELIFT_STATE_REGION:?SPACELIFT_STATE_REGION is required}"
: "${SPACELIFT_STATE_DYNAMODB_TABLE:?SPACELIFT_STATE_DYNAMODB_TABLE is required}"

WS="${REPO_ROOT}/${CLOUD}/workspaces/infra"
mkdir -p "${WS}"

cat > "${WS}/backend.tf" <<EOF
terraform {
  backend "s3" {
    bucket         = "${SPACELIFT_STATE_BUCKET}"
    key            = "${SPACELIFT_STATE_KEY}"
    region         = "${SPACELIFT_STATE_REGION}"
    dynamodb_table = "${SPACELIFT_STATE_DYNAMODB_TABLE}"
    encrypt        = true
$(if [[ -n "${SPACELIFT_STATE_ROLE_ARN:-}" ]]; then
  printf '    assume_role = {\n      role_arn = "%s"\n    }\n' "${SPACELIFT_STATE_ROLE_ARN}"
fi)
  }
}
EOF

if [[ ! -f "${WS}/main.tf" ]]; then
  cp "${WS}/main.tf.example" "${WS}/main.tf"
fi

echo "Infra before_init complete (cloud=${CLOUD}, backend + main.tf)."
