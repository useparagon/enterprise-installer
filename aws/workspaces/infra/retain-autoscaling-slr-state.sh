#!/usr/bin/env bash
# Remove the account autoscaling service-linked role from state before destroy so
# OpenTofu does not attempt iam:DeleteServiceLinkedRole (account-wide resource).
#
#   DRY_RUN=1 ./retain-autoscaling-slr-state.sh
#   ./retain-autoscaling-slr-state.sh
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

ADDR='module.cluster.aws_iam_service_linked_role.autoscaling[0]'
DRY_RUN="${DRY_RUN:-}"

if ! ${TF} state list 2>/dev/null | grep -Fxq "$ADDR"; then
  echo "Not in state (already removed or never created): $ADDR"
  exit 0
fi

if [[ -n "$DRY_RUN" ]]; then
  echo "DRY_RUN: would run: ${TF} state rm '$ADDR'"
  exit 0
fi

${TF} state rm "$ADDR"
echo "Removed from state: $ADDR"
