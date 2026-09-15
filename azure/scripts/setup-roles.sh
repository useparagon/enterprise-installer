#!/usr/bin/env bash

set -euo pipefail

# Configure these values before running the script. ORGANIZATION must match the
# `organization` Terraform variable for this deployment.
SUBSCRIPTION_ID="your-azure-subscription-id"
PRINCIPAL_ID="your-service-principal-object-id"
LOCATION="your-azure-region"
ORGANIZATION="your-organization"

# Leave empty unless an existing deployment uses a workspace name that does not
# match the derived default.
WORKSPACE=""

if [[ "${SUBSCRIPTION_ID}" == your-* || "${PRINCIPAL_ID}" == your-* || "${LOCATION}" == your-* || "${ORGANIZATION}" == your-* ]]; then
  echo "Set SUBSCRIPTION_ID, PRINCIPAL_ID, LOCATION, and ORGANIZATION before running." >&2
  exit 1
fi

for required_command in az python3; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "${required_command} is required." >&2
    exit 1
  fi
done
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  echo "shasum or sha256sum is required to derive the workspace name." >&2
  exit 1
fi

# Terraform derives the workspace name, and therefore every resource-group name
# this script scopes to, as paragon-<organization>-<first 8 of the subscription
# ID SHA-256>. Both inputs are known before the first apply, so the names are
# computed here rather than read back from Terraform state.
if [[ -z "${WORKSPACE}" ]]; then
  if command -v shasum >/dev/null 2>&1; then
    subscription_hash="$(printf '%s' "${SUBSCRIPTION_ID}" | shasum -a 256 | cut -c1-8)"
  else
    subscription_hash="$(printf '%s' "${SUBSCRIPTION_ID}" | sha256sum | cut -c1-8)"
  fi
  WORKSPACE="paragon-${ORGANIZATION}-${subscription_hash}"
fi

SUBSCRIPTION_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
RESOURCE_GROUP="${WORKSPACE}-resources"
RESOURCE_GROUP_SCOPE="${SUBSCRIPTION_SCOPE}/resourceGroups/${RESOURCE_GROUP}"
NODE_RESOURCE_GROUP="${WORKSPACE}-cluster-nodes"
NODE_RESOURCE_GROUP_SCOPE="${SUBSCRIPTION_SCOPE}/resourceGroups/${NODE_RESOURCE_GROUP}"
ROLE_NAME_SUBSCRIPTION_ID="$(printf '%s' "${SUBSCRIPTION_ID}" | tr '[:upper:]' '[:lower:]')"

CONTRIBUTOR_ROLE_ID="b24988ac-6180-42a0-ab88-20f7382dd24c"
RBAC_ADMINISTRATOR_ROLE_ID="f58310d9-a9f6-439a-9e8d-f62e7b41a168"
AKS_CLUSTER_USER_ROLE_ID="4abbcc35-e782-43d8-92c5-2d3f1bd2253f"
NETWORK_CONTRIBUTOR_ROLE_ID="4d97b98b-1d4f-4787-a291-c67834d212e7"
AKS_CLUSTER_ADMIN_ROLE_ID="0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8"
STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"
READER_ROLE_ID="acdd72a7-3385-48ef-bd42-f606fba81ae7"
AGC_CONFIG_MANAGER_ROLE_ID="fbc52c3f-28ad-4303-a892-8a056630b8f1"
DNS_ZONE_CONTRIBUTOR_ROLE_ID="befefa01-2a29-4197-83a8-272ff33ce314"
# Built-in Locks Contributor — Contributor and RBAC Administrator do not
# include Microsoft.Authorization/locks/*, which postgres_management_lock_enabled needs.
LOCKS_CONTRIBUTOR_ROLE_ID="28bf596f-4eb7-45ce-b5bc-6cf482fec137"

# Custom-role display names must be unique across the Entra tenant. Keep each
# definition subscription-specific so an administrator never needs
# roleDefinitions/write on another subscription's AssignableScopes.
PUBLIC_IP_ROLE_NAME="Paragon AKS Node Resource Group Public IP Manager (${ROLE_NAME_SUBSCRIPTION_ID})"
BOOTSTRAP_ROLE_NAME="Paragon AKS Greenfield Bootstrap (${ROLE_NAME_SUBSCRIPTION_ID})"
# Remove assignments created by pre-subscription-specific revisions, but leave
# those shared definitions in place because another subscription may use them.
LEGACY_PUBLIC_IP_ROLE_NAME="Paragon AKS Node Resource Group Public IP Manager"
LEGACY_BOOTSTRAP_ROLE_NAME="Paragon AKS Greenfield Bootstrap"

REQUIRED_PROVIDERS=(
  "Microsoft.Cache"
  "Microsoft.Compute"
  "Microsoft.ContainerService"
  "Microsoft.DBforPostgreSQL"
  "Microsoft.EventHub"
  "Microsoft.Insights"
  "Microsoft.KeyVault"
  "Microsoft.ManagedIdentity"
  "Microsoft.Network"
  "Microsoft.OperationalInsights"
  "Microsoft.ServiceNetworking"
  "Microsoft.Storage"
)

list_role_assignments() {
  local principal_id="$1"
  shift
  local assignee_flag="--assignee"
  local role_list_help

  # --assignee-object-id avoids Microsoft Graph lookup but was added to `list`
  # only in Azure CLI 2.73. Prefer it when available and retain compatibility
  # with older customer environments.
  role_list_help="$(az role assignment list --help 2>&1 || true)"
  if [[ "${role_list_help}" == *"--assignee-object-id"* ]]; then
    assignee_flag="--assignee-object-id"
  fi
  az role assignment list "${assignee_flag}" "${principal_id}" "$@"
}

role_assignment_id() {
  local role="$1"
  local scope="$2"

  list_role_assignments "${PRINCIPAL_ID}" \
    --role "${role}" \
    --scope "${scope}" \
    --query '[0].id' \
    --output tsv
}

role_assignment_ids() {
  local role="$1"
  local scope="$2"

  list_role_assignments "${PRINCIPAL_ID}" \
    --role "${role}" \
    --scope "${scope}" \
    --query '[].id' \
    --output tsv
}

ensure_role_assignment() {
  local role="$1"
  local scope="$2"
  local attempt assignment_id

  assignment_id="$(role_assignment_id "${role}" "${scope}")"
  if [[ -z "${assignment_id}" ]]; then
    # A newly created custom role can take time to become assignable. Retry the
    # assignment so a greenfield run does not fail between role creation and
    # Azure's authorization-plane propagation.
    for attempt in {1..12}; do
      if az role assignment create \
        --assignee-object-id "${PRINCIPAL_ID}" \
        --assignee-principal-type ServicePrincipal \
        --role "${role}" \
        --scope "${scope}" \
        --output none; then
        return 0
      fi
      # The create request may have succeeded even if the CLI lost the final
      # response. Avoid retrying an assignment Azure already persisted.
      if assignment_id="$(role_assignment_id "${role}" "${scope}")" \
        && [[ -n "${assignment_id}" ]]; then
        return 0
      fi
      if ((attempt == 12)); then
        echo "Failed to assign ${role} at ${scope} after ${attempt} attempts." >&2
        return 1
      fi
      echo "Role ${role} is not assignable yet; retrying in 5 seconds..." >&2
      sleep 5
    done
  fi
}

remove_role_assignment() {
  local role="$1"
  local scope="$2"
  local assignment_id assignment_ids

  assignment_ids="$(role_assignment_ids "${role}" "${scope}")"
  while IFS= read -r assignment_id; do
    [[ -n "${assignment_id}" ]] || continue
    az role assignment delete --ids "${assignment_id}"
  done <<<"${assignment_ids}"
}

remove_role_assignment_if_defined() {
  local role_name="$1"
  local scope="$2"
  local role_definition_id

  if ! role_definition_id="$(
    az role definition list \
      --name "${role_name}" \
      --query '[0].id' \
      --output tsv
  )"; then
    echo "Unable to look up optional legacy role ${role_name}." >&2
    return 1
  fi
  if [[ -n "${role_definition_id}" ]]; then
    remove_role_assignment "${role_name}" "${scope}"
  fi
}

upsert_custom_role() {
  local definition_file="$1"
  local role_name="$2"
  local existing_file existing_id existing_json

  existing_file="${definition_file}.existing.json"
  existing_json="$(az role definition list --name "${role_name}" --query '[0]' --output json)"
  if [[ -n "${existing_json}" && "${existing_json}" != "null" ]]; then
    printf '%s\n' "${existing_json}" >"${existing_file}"
  else
    printf 'null\n' >"${existing_file}"
  fi

  existing_id="$(
    python3 -c '
import json, sys
raw = open(sys.argv[1], encoding="utf-8").read().strip()
data = json.loads(raw) if raw and raw != "null" else None
print((data or {}).get("id") or "")
' "${existing_file}"
  )"

  if [[ -n "${existing_id}" ]]; then
    # az role definition update requires Id. This definition's display name is
    # subscription-specific, so its only AssignableScope is this subscription.
    python3 - "${definition_file}" "${existing_file}" "${SUBSCRIPTION_SCOPE}" <<'PY'
import json
import sys

path, existing_path, current_scope = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as handle:
    create = json.load(handle)
with open(existing_path, encoding="utf-8") as handle:
    existing = json.load(handle)

payload = {
    "Id": existing["id"],
    "Name": create["Name"],
    "IsCustom": True,
    "Description": create["Description"],
    "Actions": create["Actions"],
    "NotActions": create.get("NotActions") or [],
    "DataActions": create.get("DataActions") or [],
    "NotDataActions": create.get("NotDataActions") or [],
    "AssignableScopes": [current_scope],
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
    az role definition update --role-definition "${definition_file}" --output none
  else
    az role definition create --role-definition "${definition_file}" --output none
  fi
}

az account set --subscription "${SUBSCRIPTION_ID}"

# Terraform does not auto-register providers. Register only the namespaces used
# by the Azure workspaces, using the customer administrator running this script.
# Microsoft.ServiceNetworking is required for AGC subnet delegation
# (agc_subnet_enabled) even before the paragon AGC module is turned on.
for provider in "${REQUIRED_PROVIDERS[@]}"; do
  az provider register --namespace "${provider}" --wait
done

# Pre-create the deterministic main resource group only on greenfield. `az
# group create` is an ARM create-or-update operation: rerunning it against a
# live group can rewrite omitted properties such as tags, and a mismatched
# location fails because resource-group location is immutable.
if ! resource_group_exists="$(
  az group exists --name "${RESOURCE_GROUP}" --output tsv
)"; then
  echo "Unable to determine whether resource group ${RESOURCE_GROUP} exists." >&2
  exit 1
fi
if [[ "${resource_group_exists}" == "true" ]]; then
  echo "Resource group ${RESOURCE_GROUP} already exists; leaving it untouched."
elif [[ "${resource_group_exists}" == "false" ]]; then
  az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --output none
else
  echo "Unexpected az group exists output for ${RESOURCE_GROUP}: ${resource_group_exists}" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

cat >"${tmp_dir}/public-ip-role.json" <<EOF
{
  "Name": "${PUBLIC_IP_ROLE_NAME}",
  "IsCustom": true,
  "Description": "Manage only Terraform-owned ingress public IP resources in an AKS node resource group.",
  "Actions": [
    "Microsoft.Network/publicIPAddresses/read",
    "Microsoft.Network/publicIPAddresses/write",
    "Microsoft.Network/publicIPAddresses/delete",
    "Microsoft.Network/publicIPAddresses/join/action",
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": ["${SUBSCRIPTION_SCOPE}"]
}
EOF

cat >"${tmp_dir}/bootstrap-role.json" <<EOF
{
  "Name": "${BOOTSTRAP_ROLE_NAME}",
  "IsCustom": true,
  "Description": "Temporary greenfield permission for AKS to create its node resource group and for Terraform to create the ingress public IP.",
  "Actions": [
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Resources/subscriptions/resourceGroups/write",
    "Microsoft.Network/publicIPAddresses/read",
    "Microsoft.Network/publicIPAddresses/write",
    "Microsoft.Network/publicIPAddresses/delete",
    "Microsoft.Network/publicIPAddresses/join/action"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": ["${SUBSCRIPTION_SCOPE}"]
}
EOF

upsert_custom_role "${tmp_dir}/public-ip-role.json" "${PUBLIC_IP_ROLE_NAME}"

ensure_role_assignment "${CONTRIBUTOR_ROLE_ID}" "${RESOURCE_GROUP_SCOPE}"
ensure_role_assignment "${AKS_CLUSTER_USER_ROLE_ID}" "${RESOURCE_GROUP_SCOPE}"
ensure_role_assignment "${LOCKS_CONTRIBUTOR_ROLE_ID}" "${RESOURCE_GROUP_SCOPE}"

# Recreate the RBAC Administrator assignment to guarantee that it has the
# current condition instead of inheriting a stale or unconstrained assignment.
remove_role_assignment "${RBAC_ADMINISTRATOR_ROLE_ID}" "${RESOURCE_GROUP_SCOPE}"
# Roles Terraform actually assigns in the Paragon resource group (including AGC
# and Azure DNS). The SP cannot register providers; that is handled above.
ASSIGNABLE_ROLE_IDS="${NETWORK_CONTRIBUTOR_ROLE_ID}, ${AKS_CLUSTER_ADMIN_ROLE_ID}, ${STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID}, ${READER_ROLE_ID}, ${AGC_CONFIG_MANAGER_ROLE_ID}, ${DNS_ZONE_CONTRIBUTOR_ROLE_ID}"
RBAC_CONDITION="((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${ASSIGNABLE_ROLE_IDS}})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${ASSIGNABLE_ROLE_IDS}}))"
az role assignment create \
  --assignee-object-id "${PRINCIPAL_ID}" \
  --assignee-principal-type ServicePrincipal \
  --role "${RBAC_ADMINISTRATOR_ROLE_ID}" \
  --scope "${RESOURCE_GROUP_SCOPE}" \
  --condition "${RBAC_CONDITION}" \
  --condition-version "2.0" \
  --output none

if ! node_resource_group_exists="$(
  az group exists --name "${NODE_RESOURCE_GROUP}" --output tsv
)"; then
  echo "Unable to determine whether node resource group ${NODE_RESOURCE_GROUP} exists." >&2
  exit 1
fi
if [[ "${node_resource_group_exists}" == "true" ]]; then
  ensure_role_assignment "${PUBLIC_IP_ROLE_NAME}" "${NODE_RESOURCE_GROUP_SCOPE}"
  remove_role_assignment_if_defined "${BOOTSTRAP_ROLE_NAME}" "${SUBSCRIPTION_SCOPE}"
  remove_role_assignment_if_defined "${LEGACY_PUBLIC_IP_ROLE_NAME}" "${NODE_RESOURCE_GROUP_SCOPE}"
  remove_role_assignment_if_defined "${LEGACY_BOOTSTRAP_ROLE_NAME}" "${SUBSCRIPTION_SCOPE}"
  echo "Scoped public-IP access to ${NODE_RESOURCE_GROUP}; no bootstrap subscription assignment remains."
elif [[ "${node_resource_group_exists}" == "false" ]]; then
  upsert_custom_role "${tmp_dir}/bootstrap-role.json" "${BOOTSTRAP_ROLE_NAME}"
  ensure_role_assignment "${BOOTSTRAP_ROLE_NAME}" "${SUBSCRIPTION_SCOPE}"
  remove_role_assignment_if_defined "${LEGACY_BOOTSTRAP_ROLE_NAME}" "${SUBSCRIPTION_SCOPE}"
  echo "The AKS node resource group does not exist yet."
  echo "A minimal temporary subscription role was assigned for greenfield creation."
  echo "Run this script again after the infra workspace succeeds to replace it with node-resource-group scope."
else
  echo "Unexpected az group exists output for ${NODE_RESOURCE_GROUP}: ${node_resource_group_exists}" >&2
  exit 1
fi

# Remove the former broad assignments after the scoped replacements exist.
# Keep subscription User Access Administrator while a subscription-scoped
# Reader still exists on the support identity — destroying that assignment
# needs roleAssignments/delete at subscription scope.
remove_role_assignment "Contributor" "${SUBSCRIPTION_SCOPE}"
remove_role_assignment "Azure Kubernetes Service Cluster User Role" "${SUBSCRIPTION_SCOPE}"

hoop_support_principal=""
hoop_subscription_reader=""
if hoop_support_principal="$(
  az identity show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${WORKSPACE}-hoop-support" \
    --query principalId \
    --output tsv 2>/dev/null
)" && [[ -n "${hoop_support_principal}" ]]; then
  hoop_subscription_reader="$(
    list_role_assignments "${hoop_support_principal}" \
      --role "${READER_ROLE_ID}" \
      --scope "${SUBSCRIPTION_SCOPE}" \
      --query '[0].id' \
      --output tsv
  )"
fi

if [[ -n "${hoop_subscription_reader}" ]]; then
  echo "Leaving subscription User Access Administrator in place until Terraform"
  echo "moves the support identity Reader from the subscription to ${RESOURCE_GROUP}."
  echo
  echo "REQUIRED after the paragon workspace apply succeeds: run this script again"
  echo "in the same subscription. The second run removes User Access Administrator"
  echo "once the support identity Reader is only on ${RESOURCE_GROUP}."
  echo "Until that rerun, the principal still holds subscription User Access Administrator."
else
  remove_role_assignment "User Access Administrator" "${SUBSCRIPTION_SCOPE}"
fi

cat <<EOF

Workspace: ${WORKSPACE}

Permanent access:
  - Contributor: ${RESOURCE_GROUP_SCOPE}
  - Constrained RBAC Administrator: ${RESOURCE_GROUP_SCOPE}
  - AKS Cluster User: ${RESOURCE_GROUP_SCOPE}
  - Locks Contributor: ${RESOURCE_GROUP_SCOPE} (postgres_management_lock_enabled)
  - Public IP Manager: ${NODE_RESOURCE_GROUP_SCOPE} (after the node group exists)

Terraform may assign only these roles inside the main resource group:
  - Network Contributor
  - Azure Kubernetes Service Cluster Admin Role
  - Storage Blob Data Contributor
  - Reader
  - AppGw for Containers Configuration Manager (AGC)
  - DNS Zone Contributor (dns_provider=azure_dns)
EOF
