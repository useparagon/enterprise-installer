#!/usr/bin/env bash
# Re-import the Paragon app (private) S3 bucket into state after retain-app-bucket-state.sh.
#
# Prerequisites: infra stack config matches live AWS (workspace, migrated, KMS flags).
# Other module.storage resources (logs bucket, IAM, etc.) should still be in state.
#
# Set the bucket name explicitly, or set WORKSPACE and optional MIGRATED=1:
#   MIGRATED=1 matches var.migrated (bucket = workspace, not workspace-app).
#
#   APP_BUCKET_NAME=paragon-example-a1b2c3d4-app ./import-app-bucket-state.sh
#   WORKSPACE=paragon-example-a1b2c3d4 ./import-app-bucket-state.sh
#   DRY_RUN=1 ./import-app-bucket-state.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ -n "${SPACELIFT_STATE_BUCKET:-}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  "${REPO_ROOT}/scripts/spacelift/before_init-infra.sh" aws
fi

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "tofu or terraform required." >&2
  exit 1
fi

if [[ -n "${APP_BUCKET_NAME:-}" ]]; then
  BUCKET="${APP_BUCKET_NAME}"
elif [[ -n "${WORKSPACE:-}" ]]; then
  if [[ "${MIGRATED:-0}" == "1" ]]; then
    BUCKET="${WORKSPACE}"
  else
    BUCKET="${WORKSPACE}-app"
  fi
else
  echo "Set APP_BUCKET_NAME or WORKSPACE (and MIGRATED=1 if the live bucket has no -app suffix)." >&2
  exit 1
fi

${TF} init -input=false

# Same resources as retain-app-bucket-state.sh — import order: bucket first, then settings.
IMPORTS=(
  "module.storage.aws_s3_bucket.app"
  "module.storage.aws_s3_bucket_ownership_controls.app"
  "module.storage.aws_s3_bucket_server_side_encryption_configuration.app"
  "module.storage.aws_s3_bucket_versioning.app"
  "module.storage.aws_s3_bucket_public_access_block.app"
  "module.storage.aws_s3_bucket_logging.app"
  "module.storage.aws_s3_bucket_lifecycle_configuration.app"
  "module.storage.aws_s3_bucket_policy.app"
)

in_state() {
  ${TF} state show "$1" >/dev/null 2>&1
}

for addr in "${IMPORTS[@]}"; do
  if in_state "${addr}"; then
    echo "skip (already in state): ${addr}"
    continue
  fi
  echo "import: ${addr} <- ${BUCKET}"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    continue
  fi
  ${TF} import -input=false "${addr}" "${BUCKET}"
done

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "DRY_RUN=1 — no imports run."
  exit 0
fi

echo "Done. Run ${TF} plan -input=false and reconcile any drift (lifecycle days, KMS, logging target)."
