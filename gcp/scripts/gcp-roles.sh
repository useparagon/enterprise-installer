#!/bin/bash

# Script to assign roles to a service account within a GCP project using `gcloud`.
# Documents the minimum roles for the Terraform principal (infra + paragon workspaces).
#
# Bastion / CLI diagnostics roles are listed separately below — assign those to the bastion
# service account (Terraform already does this for the default bastion), not as a substitute
# for the Terraform installer SA roles.
#
# Enable required APIs in the console (or via gcloud) before apply — this repo does not
# enable APIs during Terraform. See gcp/workspaces/infra/README.md.

# Define the project ID and service account email
PROJECT_ID="your-gcp-project-id"
SERVICE_ACCOUNT="your-service-account@something.iam.gserviceaccount.com"

# Roles required for Terraform (infra + paragon)
ROLES=(
   "roles/cloudsql.admin"                    # Cloud SQL
   "roles/compute.admin"                     # VPC, firewall, addresses, Cloud Armor, LB-related compute
   "roles/container.admin"                   # GKE cluster + Helm/K8s (covers container.developer)
   "roles/container.clusterAdmin"            # Cluster-level admin operations
   "roles/gkehub.editor"                     # Register the private GKE cluster with Fleet
   "roles/gkehub.gatewayEditor"              # Reach the private GKE API through Connect Gateway
   "roles/iam.serviceAccountAdmin"           # Create workload SAs
   "roles/iam.serviceAccountKeyAdmin"        # Optional SA keys (storage / Kafka SASL PLAIN)
   "roles/iam.serviceAccountUser"            # Attach / impersonate SAs
   "roles/redis.admin"                       # Memorystore Redis
   "roles/resourcemanager.projectIamAdmin"   # IAM bindings (bastion, installer, node SA, WI, ESO)
   "roles/secretmanager.admin"               # Infra + app Secret Manager secrets/versions
   "roles/storage.admin"                     # GCS buckets + bucket IAM
)

# Optional — only when managed sync / Google Managed Kafka is enabled
# ROLES+=("roles/managedkafka.admin")

# Optional — only if Cloud DNS (not Cloudflare) manages records in-project
# ROLES+=("roles/dns.admin")

# Bastion diagnostics / ops (assigned to the bastion SA by infra Terraform by default).
# Do NOT put these on the Terraform installer SA as a substitute for the list above.
# BASTION_ROLES=(
#   "roles/container.admin"              # kubectl against the cluster
#   "roles/compute.loadBalancerAdmin"    # describe/update GCLB certs and HTTPS proxies
# )

# Loop through each role and assign it to the service account
for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="$ROLE"
done
