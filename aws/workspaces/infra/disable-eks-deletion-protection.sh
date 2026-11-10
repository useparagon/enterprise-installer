#!/usr/bin/env bash
# Disable EKS cluster deletion protection before infra destroy. The terraform-aws-eks
# module pin (v20.26) does not expose deletion_protection on aws ~> 5.x yet.
#
#   WORKSPACE=paragon-enterprise-isms-us AWS_REGION=us-east-2 ./disable-eks-deletion-protection.sh
#   DRY_RUN=1 ./disable-eks-deletion-protection.sh
set -euo pipefail

: "${WORKSPACE:?set WORKSPACE (EKS cluster name)}"
: "${AWS_REGION:?set AWS_REGION}"

DRY_RUN="${DRY_RUN:-}"

status="$(aws eks describe-cluster --name "$WORKSPACE" --region "$AWS_REGION" \
  --query 'cluster.deletionProtection' --output text 2>/dev/null || echo "")"

if [[ "$status" == "None" || -z "$status" ]]; then
  echo "Cluster $WORKSPACE: deletion protection attribute not set or cluster missing; nothing to do."
  exit 0
fi

if [[ "$status" == "DISABLED" || "$status" == "false" || "$status" == "False" ]]; then
  echo "Cluster $WORKSPACE: deletion protection already disabled."
  exit 0
fi

echo "Cluster $WORKSPACE: disabling deletion protection (current: $status)"
if [[ -n "$DRY_RUN" ]]; then
  echo "DRY_RUN: would run aws eks update-cluster-config --no-deletion-protection"
  exit 0
fi

aws eks update-cluster-config \
  --name "$WORKSPACE" \
  --region "$AWS_REGION" \
  --no-deletion-protection

echo "Waiting for cluster update to complete..."
aws eks wait cluster-active --name "$WORKSPACE" --region "$AWS_REGION"
echo "Done."
