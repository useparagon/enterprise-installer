#!/usr/bin/env bash
# Spacelift before_init for aws/workspaces/paragon.
#
# Required env (set via Spacelift stack context / env):
#   PARAGON_CHART_TAG          Git tag for prepare.sh -t (chart/app version)
#   SPACELIFT_STATE_BUCKET     S3 backend bucket
#   SPACELIFT_STATE_KEY        e.g. <customer-id>/paragon.tfstate
#   SPACELIFT_STATE_REGION     e.g. us-east-2
#   SPACELIFT_STATE_DYNAMODB_TABLE
# Optional:
#   SPACELIFT_STATE_ROLE_ARN   backend access role (if not using Spacelift AWS integration alone)
#
# Also set TF_VAR_helm_yaml_path (mounted paragon-values.yaml) and
# TF_VAR_aws_assume_role_arn in context.
# service-inputs.json is fetched from s3://$SPACELIFT_STATE_BUCKET/<customer>/service-inputs.json
# (uploaded by migrate:state-copy — too large for Spacelift GraphQL file mounts).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# When run from project_root (aws/workspaces/paragon), repo root is three levels up.
if [[ -f "${REPO_ROOT}/prepare.sh" ]]; then
  :
elif [[ -f "$(pwd)/../../../prepare.sh" ]]; then
  REPO_ROOT="$(cd "$(pwd)/../../.." && pwd)"
elif [[ -f "./prepare.sh" ]]; then
  REPO_ROOT="$(pwd)"
else
  # Spacelift checks out repo root; project_root is aws/workspaces/paragon
  REPO_ROOT="$(cd "$(pwd)/../../.." && pwd)"
fi

cd "${REPO_ROOT}"

: "${PARAGON_CHART_TAG:?PARAGON_CHART_TAG is required (git tag for ./prepare.sh -t)}"
: "${SPACELIFT_STATE_BUCKET:?SPACELIFT_STATE_BUCKET is required}"
: "${SPACELIFT_STATE_KEY:?SPACELIFT_STATE_KEY is required}"
: "${SPACELIFT_STATE_REGION:?SPACELIFT_STATE_REGION is required}"
: "${SPACELIFT_STATE_DYNAMODB_TABLE:?SPACELIFT_STATE_DYNAMODB_TABLE is required}"

WS="${REPO_ROOT}/aws/workspaces/paragon"
mkdir -p "${WS}"

# Inject S3 backend (unique key per customer). Overwrite each run so keys stay correct.
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

# Ensure terraform{} / providers block exists (gitignored main.tf).
if [[ ! -f "${WS}/main.tf" ]]; then
  cp "${WS}/main.tf.example" "${WS}/main.tf"
fi

echo "Running prepare.sh -p aws -t ${PARAGON_CHART_TAG}"
# Spacelift local-preview / shallow checkouts have no git tags. Prefer an
# explicit mount, else download the object uploaded next to state by state-copy.
if [[ -f /mnt/workspace/service-inputs.json ]]; then
  export PARAGON_SERVICE_INPUTS_JSON=/mnt/workspace/service-inputs.json
elif [[ -z "${PARAGON_SERVICE_INPUTS_JSON:-}" ]]; then
  # SPACELIFT_STATE_KEY is <customer>/paragon.tfstate → <customer>/service-inputs.json
  si_key="${SPACELIFT_STATE_KEY%/*}/service-inputs.json"
  # GNU mktemp requires the X's at the end of the template.
  si_local="$(mktemp -t service-inputs.XXXXXX)"
  echo "Downloading s3://${SPACELIFT_STATE_BUCKET}/${si_key}"
  # Scope assumed-role creds to this download only — do not export into the
  # rest of before_init (provider uses TF_VAR_aws_assume_role_arn separately).
  if [[ -n "${SPACELIFT_STATE_ROLE_ARN:-}" ]]; then
    read -r aws_access_key_id aws_secret_access_key aws_session_token < <(
      aws sts assume-role \
        --role-arn "${SPACELIFT_STATE_ROLE_ARN}" \
        --role-session-name "spacelift-before-init-paragon" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text
    )
    AWS_ACCESS_KEY_ID="${aws_access_key_id}" \
      AWS_SECRET_ACCESS_KEY="${aws_secret_access_key}" \
      AWS_SESSION_TOKEN="${aws_session_token}" \
      aws s3 cp "s3://${SPACELIFT_STATE_BUCKET}/${si_key}" "${si_local}" \
      --region "${SPACELIFT_STATE_REGION}"
  else
    aws s3 cp "s3://${SPACELIFT_STATE_BUCKET}/${si_key}" "${si_local}" \
      --region "${SPACELIFT_STATE_REGION}"
  fi
  export PARAGON_SERVICE_INPUTS_JSON="${si_local}"
fi
./prepare.sh -p aws -t "${PARAGON_CHART_TAG}"

# prepare.sh writes placeholder *.auto.tfvars for local use. Those files outrank
# TF_VAR_* from Spacelift context — remove them so stack env wins.
rm -f "${WS}/vars.auto.tfvars"
rm -f "${REPO_ROOT}/aws/workspaces/infra/vars.auto.tfvars"

# Fail closed if chart version substitution did not run (e.g. broken sed on worker).
if [[ ! -d "${WS}/charts" ]] || [[ -z "$(find "${WS}/charts" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]]; then
  echo "ERROR: no charts under ${WS}/charts after prepare.sh" >&2
  exit 1
fi
if grep -rql '__PARAGON_VERSION__' "${WS}/charts" 2>/dev/null; then
  echo "ERROR: __PARAGON_VERSION__ placeholders remain under ${WS}/charts after prepare.sh" >&2
  exit 1
fi

# Placeholder .secure/values.yaml from prepare is NOT sufficient for LICENSE/VERSION.
if [[ -z "${TF_VAR_helm_yaml_path:-}" && -z "${TF_VAR_helm_yaml:-}" ]]; then
  echo "WARNING: TF_VAR_helm_yaml_path (or TF_VAR_helm_yaml) is unset. Mount paragon-values.yaml via migrate:state-copy." >&2
fi

echo "Paragon before_init complete."
