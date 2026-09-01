#!/bin/bash

# Script to assign roles to a service principal or user within an Azure subscription using `az cli`.
# This script documents the minimum required permissions to run the Azure infra and paragon Terraform workspaces.

# Define variables
SUBSCRIPTION_ID="your-azure-subscription-id"
PRINCIPAL_ID="your-service-principal-object-id-or-user-object-id"

# Roles required for Terraform (infra + paragon)
# Key Vault uses the access-policy model (not RBAC) by default: Contributor can create the vault
# and access policies. Do not require Key Vault Administrator unless the vault is switched to RBAC.
ROLES=(
  # Create/manage RGs, networking, AKS, Postgres, Redis, Storage, Key Vault, Public IPs, bastion VMSS, Event Hubs
  "Contributor"
  # Microsoft.Authorization/roleAssignments/write — AKS Network Contributor on subnet/NSG,
  # Managed Redis export storage RBAC. Without this, infra apply fails with 403.
  "User Access Administrator"
  # listClusterUserCredential for Helm / Kubernetes providers in the paragon workspace
  "Azure Kubernetes Service Cluster User Role"
)

# The bastion does not use this subscription-level role list. Infra Terraform
# assigns its managed identity Azure Kubernetes Service Cluster Admin Role at
# the individual cluster scope.

# Alternative: If you want to use more granular permissions instead of Contributor,
# you would need the following roles (but Contributor is simpler and sufficient):
#
# GRANULAR_ROLES=(
#   "Network Contributor"              # For Virtual Networks, Subnets, NSGs, Private Endpoints
#   "DNS Zone Contributor"             # For Private DNS Zones
#   "PostgreSQL Flexible Server Contributor"  # For PostgreSQL Flexible Servers
#   "Redis Cache Contributor"          # For Redis Caches
#   "Storage Account Contributor"      # For Storage Accounts
#   "Kubernetes Cluster Contributor"   # For AKS Clusters
#   "Virtual Machine Contributor"      # For VM Scale Sets (bastion)
#   "Key Vault Contributor"            # For Key Vaults (management plane)
#   "User Access Administrator"        # For role assignments (RBAC)
#   "Azure Kubernetes Service Cluster User Role"
# )

for ROLE in "${ROLES[@]}"; do
  echo "Assigning role '$ROLE' to principal $PRINCIPAL_ID..."
  az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "$ROLE" \
    --scope "/subscriptions/$SUBSCRIPTION_ID"
done

echo ""
echo "Role assignment complete!"
echo ""
echo "Note: The Contributor role provides the following permissions needed for Terraform:"
echo "  - Create and manage Resource Groups"
echo "  - Create and manage Virtual Networks, Subnets, and Network Security Groups"
echo "  - Create and manage Private DNS Zones and Private Endpoints"
echo "  - Create and manage PostgreSQL Flexible Servers"
echo "  - Create and manage Redis Caches / Managed Redis"
echo "  - Create and manage Storage Accounts and Containers"
echo "  - Create and manage AKS Clusters and Node Pools"
echo "  - Create and manage Virtual Machine Scale Sets"
echo "  - Create and manage Key Vaults + access policies (default permission model)"
echo "  - Create and manage Event Hubs (managed sync / Kafka protocol)"
echo "  - Create and manage Public IPs"
echo ""
echo "User Access Administrator is required so Terraform can assign:"
echo "  - Network Contributor to the AKS MI on the private subnet and aks-nsg"
echo "  - Storage Blob Data Contributor to Managed Redis export storage (when enabled)"
echo ""
echo "Azure Kubernetes Service Cluster User Role is required for the paragon workspace"
echo "to authenticate to the AKS API for Helm installs."
echo ""
echo "If the customer refuses User Access Administrator, they must run equivalent scoped"
echo "az role assignment create commands themselves before/during infra apply."
echo ""
echo "The bastion managed identity receives Cluster Admin at cluster scope from infra Terraform."
echo "It is separate from this Terraform principal policy."
