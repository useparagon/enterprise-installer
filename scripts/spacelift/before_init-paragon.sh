#!/usr/bin/env bash
# Spacelift before_init for aws/workspaces/paragon.
#
# Required env (set via Spacelift stack context / env):
#   SPACELIFT_STATE_BUCKET     S3 backend bucket
#   SPACELIFT_STATE_KEY        e.g. <customer-id>/paragon.tfstate
#   SPACELIFT_STATE_REGION     e.g. us-east-2
#   SPACELIFT_STATE_DYNAMODB_TABLE
# Optional:
#   SPACELIFT_STATE_ROLE_ARN   backend access role (if not using Spacelift AWS integration alone)
#   PARAGON_CHART_TAG          Override release tag (default: global.env.VERSION from values)
#   PARAGON_SERVICE_INPUTS_JSON  Path to service-inputs.json (skip git fetch)
#
# Also set TF_VAR_helm_yaml_path (mounted paragon-values.yaml) and
# TF_VAR_aws_assume_role_arn in context.
#
# service-inputs.json is taken from the release git tag matching VERSION
# (charts/files/service-inputs.json). local-preview packs the working tree
# without .git, so there either mount /mnt/workspace/service-inputs.json or
# leave a copy at charts/files/service-inputs.json to be packed with it.
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

: "${SPACELIFT_STATE_BUCKET:?SPACELIFT_STATE_BUCKET is required}"
: "${SPACELIFT_STATE_KEY:?SPACELIFT_STATE_KEY is required}"
: "${SPACELIFT_STATE_REGION:?SPACELIFT_STATE_REGION is required}"
: "${SPACELIFT_STATE_DYNAMODB_TABLE:?SPACELIFT_STATE_DYNAMODB_TABLE is required}"

# Resolve release tag: PARAGON_CHART_TAG override, else VERSION from mounted values.
resolve_chart_tag() {
  if [[ -n "${PARAGON_CHART_TAG:-}" ]]; then
    printf '%s' "${PARAGON_CHART_TAG}"
    return 0
  fi

  local values_file=""
  if [[ -n "${TF_VAR_helm_yaml_path:-}" && -f "${TF_VAR_helm_yaml_path}" ]]; then
    values_file="${TF_VAR_helm_yaml_path}"
  elif [[ -f /mnt/workspace/paragon-values.yaml ]]; then
    values_file=/mnt/workspace/paragon-values.yaml
  fi

  if [[ -z "${values_file}" ]]; then
    echo "ERROR: set PARAGON_CHART_TAG or mount paragon-values.yaml (TF_VAR_helm_yaml_path) with global.env.VERSION" >&2
    return 1
  fi

  local version
  version="$(sed -nE 's/^[[:space:]]*VERSION:[[:space:]]*["'\'']?([^[:space:]"'\'']+).*/\1/p' "${values_file}" | head -n 1)"
  if [[ -z "${version}" ]]; then
    echo "ERROR: VERSION not found in ${values_file}" >&2
    return 1
  fi
  printf '%s' "${version}"
}

CHART_TAG="$(resolve_chart_tag)"

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

# Resolve service-inputs.json for prepare.sh:
# 1) explicit env / mount (local-preview)
# 2) git show from the release tag (tracked VCS runs)
# 3) charts/files/service-inputs.json in the workspace (local-preview packs the
#    working tree without .git, so the tag fetch in 2 is unavailable there)
if [[ -n "${PARAGON_SERVICE_INPUTS_JSON:-}" && -f "${PARAGON_SERVICE_INPUTS_JSON}" ]]; then
  echo "Using service-inputs from PARAGON_SERVICE_INPUTS_JSON=${PARAGON_SERVICE_INPUTS_JSON}"
elif [[ -f /mnt/workspace/service-inputs.json ]]; then
  export PARAGON_SERVICE_INPUTS_JSON=/mnt/workspace/service-inputs.json
  echo "Using service-inputs from /mnt/workspace/service-inputs.json"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Fetching git tag ${CHART_TAG} for service-inputs.json"
  if ! git fetch --depth 1 origin "refs/tags/${CHART_TAG}:refs/tags/${CHART_TAG}"; then
    echo "ERROR: failed to fetch tag ${CHART_TAG} from origin" >&2
    exit 1
  fi

  # GNU mktemp requires the X's at the end of the template.
  si_local="$(mktemp -t service-inputs.XXXXXX)"
  if ! git show "${CHART_TAG}:charts/files/service-inputs.json" > "${si_local}"; then
    echo "ERROR: charts/files/service-inputs.json not found on tag ${CHART_TAG}" >&2
    rm -f "${si_local}"
    exit 1
  fi
  export PARAGON_SERVICE_INPUTS_JSON="${si_local}"
  echo "Extracted service-inputs.json from tag ${CHART_TAG}"
elif [[ -f "${REPO_ROOT}/charts/files/service-inputs.json" ]]; then
  export PARAGON_SERVICE_INPUTS_JSON="${REPO_ROOT}/charts/files/service-inputs.json"
  echo "Using service-inputs from packed workspace charts/files/service-inputs.json"
  echo "WARNING: service-inputs.json came from the packed workspace, not tag ${CHART_TAG}." >&2
else
  echo "ERROR: no .git checkout and no service-inputs.json available." >&2
  echo "  Tracked Spacelift runs fetch charts/files/service-inputs.json from tag ${CHART_TAG}." >&2
  echo "  For local-preview, extract it into the working tree before packing:" >&2
  echo "    git fetch --tags && mkdir -p charts/files && \\" >&2
  echo "    git show ${CHART_TAG}:charts/files/service-inputs.json > charts/files/service-inputs.json" >&2
  echo "  Or mount it at /mnt/workspace/service-inputs.json / set PARAGON_SERVICE_INPUTS_JSON." >&2
  exit 1
fi

echo "Running prepare.sh -p aws -t ${CHART_TAG}"
./prepare.sh -p aws -t "${CHART_TAG}"

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
