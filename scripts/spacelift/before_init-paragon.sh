#!/usr/bin/env bash
# Spacelift before_init for <cloud>/workspaces/paragon.
#
# Usage (from cloud entrypoint): before_init-paragon.sh <aws|azure|gcp>
# Or set SPACELIFT_CLOUD. Default remains aws for legacy callers.
#
# Required env:
#   SPACELIFT_STATE_BUCKET
#   SPACELIFT_STATE_KEY
#   SPACELIFT_STATE_REGION
#   SPACELIFT_STATE_DYNAMODB_TABLE
# Optional:
#   SPACELIFT_STATE_ROLE_ARN
#   PARAGON_CHART_TAG
#   PARAGON_SERVICE_INPUTS_JSON
#
# Also set TF_VAR_helm_yaml_path (mounted paragon-values.yaml).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -f "${REPO_ROOT}/prepare.sh" ]]; then
  :
elif [[ -f "$(pwd)/../../../prepare.sh" ]]; then
  REPO_ROOT="$(cd "$(pwd)/../../.." && pwd)"
elif [[ -f "./prepare.sh" ]]; then
  REPO_ROOT="$(pwd)"
else
  REPO_ROOT="$(cd "$(pwd)/../../.." && pwd)"
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

WS="${REPO_ROOT}/${CLOUD}/workspaces/paragon"
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

echo "Running prepare.sh -p ${CLOUD} -t ${CHART_TAG}"
./prepare.sh -p "${CLOUD}" -t "${CHART_TAG}"

rm -f "${WS}/vars.auto.tfvars"
rm -f "${REPO_ROOT}/${CLOUD}/workspaces/infra/vars.auto.tfvars"

if [[ ! -d "${WS}/charts" ]] || [[ -z "$(find "${WS}/charts" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]]; then
  echo "ERROR: no charts under ${WS}/charts after prepare.sh" >&2
  exit 1
fi
if grep -rql '__PARAGON_VERSION__' "${WS}/charts" 2>/dev/null; then
  echo "ERROR: __PARAGON_VERSION__ placeholders remain under ${WS}/charts after prepare.sh" >&2
  exit 1
fi

if [[ -z "${TF_VAR_helm_yaml_path:-}" && -z "${TF_VAR_helm_yaml:-}" ]]; then
  echo "WARNING: TF_VAR_helm_yaml_path (or TF_VAR_helm_yaml) is unset. Mount paragon-values.yaml for greenfield/migration." >&2
fi

echo "Paragon before_init complete (cloud=${CLOUD})."
