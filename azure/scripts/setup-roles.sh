#!/bin/bash

# Assign subscription-scoped Azure RBAC for the principal that runs Paragon enterprise
# Terraform (e.g. Spacelift Azure integration app) and for operational diagnostics.
#
# Provisioning: Contributor + User Access Administrator cover ARM for AKS, Postgres,
# Redis, storage, networking, VMSS, etc., plus Key Vault RBAC / role assignments.
#
# Kubernetes API: Contributor does NOT grant access to the Kubernetes control plane when
# using Azure RBAC for Kubernetes. "Azure Kubernetes Service Cluster User Role" allows
# obtaining a kubeconfig and read-oriented kubectl (e.g. inspect cert-manager Certificates,
# ingress, events) subject to Kubernetes RBAC inside the cluster.
#
# Key Vault data plane: To read secret/certificate *values* (not just manage the vault
# resource), also assign a data-plane role at the vault scope (e.g. Key Vault Administrator
# or Key Vault Secrets User) — subscription roles alone are not enough for secret content.

SUBSCRIPTION_ID="your-azure-subscription-id"
PRINCIPAL_ID="your-service-principal-object-id-or-user-object-id"

ROLES=(
  # Full resource management except IAM grants (Terraform apply/destroy)
  "Contributor"
  # Needed to create role assignments (Key Vault RBAC + AKS Network Contributor on subnet/NSG)
  "User Access Administrator"
  # kubectl / Kubernetes API via Azure RBAC (cluster inspection, certs, events, logs)
  "Azure Kubernetes Service Cluster User Role"
)

# Optional: tighter scope than Contributor (more roles to maintain):
#
# GRANULAR_ROLES=(
#   "Network Contributor"
#   "DNS Zone Contributor"
#   "PostgreSQL Flexible Server Contributor"
#   "Redis Cache Contributor"
#   "Storage Account Contributor"
#   "Kubernetes Cluster Contributor"
#   "Virtual Machine Contributor"
#   "Key Vault Contributor"
#   "Key Vault Administrator"
#   "User Access Administrator"
# )

for ROLE in "${ROLES[@]}"; do
  echo "Assigning role '$ROLE' to principal $PRINCIPAL_ID..."
  az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "$ROLE" \
    --scope "/subscriptions/$SUBSCRIPTION_ID"
done

echo ""
echo "Role assignment complete."
echo ""
echo "Contributor: ARM for resource groups, VNet/NSG/DNS, private endpoints, Postgres,"
echo "  Redis, storage, AKS node pools, VMSS (bastion), public IPs, etc."
echo "User Access Administrator: Key Vault RBAC transitions and Azure RBAC assignments."
echo "AKS Cluster User: Kubernetes API access for diagnostics (e.g. cert-manager, ingress)."
echo ""
echo "For Key Vault RBAC (permission model change + role assignments),"
echo "and for AKS Network Contributor on the private subnet (ingress LB),"
echo "Terraform also needs User Access Administrator at subscription or resource group scope."
echo ""
echo "If you want the Terraform principal to manage Key Vault secrets/certs/keys,"
echo "assign Key Vault Administrator at the vault scope."
echo ""
echo "On apply, infra grants the AKS cluster identity Network Contributor on the"
echo "private subnet and aks-nsg so LoadBalancer / VMSS subnet join and NSG"
echo "rule reconciliation succeed."
