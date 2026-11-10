#!/usr/bin/env bash
# One-off: remove the Paragon app (private) S3 bucket from OpenTofu/Terraform state
# so infra destroy does not delete the bucket or its policy/lifecycle in AWS.
#
# Run from this directory after backend is configured (or on Spacelift with same
# SPACELIFT_STATE_* env as before_init):
#
#   DRY_RUN=1 ./retain-app-bucket-state.sh
#   ./retain-app-bucket-state.sh
#
# Reverse: import-app-bucket-state.sh (APP_BUCKET_NAME or WORKSPACE).
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

${TF} init -input=false

# App private bucket and every S3 sub-resource Terraform manages for it.
APP_PATTERN='^module\.storage\.(aws_s3_bucket\.app|aws_s3_bucket_(logging|ownership_controls|server_side_encryption_configuration|versioning|public_access_block|lifecycle_configuration|policy)\.app)'

ADDRS=()
while IFS= read -r addr; do
  [[ -n "${addr}" ]] || continue
  [[ "${addr}" =~ ${APP_PATTERN} ]] && ADDRS+=("${addr}")
done < <(${TF} state list | LC_ALL=C sort)

if [[ ${#ADDRS[@]} -eq 0 ]]; then
  echo "No app bucket addresses in state (already removed or different module path)."
  exit 0
fi

echo "Removing ${#ADDRS[@]} addresses from state:"
printf '  %s\n' "${ADDRS[@]}"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "DRY_RUN=1 — no changes."
  exit 0
fi

for addr in "${ADDRS[@]}"; do
  echo "state rm: ${addr}"
  ${TF} state rm "${addr}"
done

echo "Done. App bucket is no longer in state; run infra destroy when ready."
