variable "workspace" {
  description = "Workspace name used for resource naming."
  type        = string
}

variable "azure_location" {
  description = "Azure region."
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure subscription ID."
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure AD tenant ID."
  type        = string
  sensitive   = true
}

variable "azure_resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
}

variable "azure_node_resource_group" {
  description = "Name of the AKS node resource group (MC_* group)."
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federation."
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault used for secrets."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Azure Key Vault (for access policies and secret creation)."
  type        = string
}

variable "key_vault_uri" {
  description = "URI of the Azure Key Vault (e.g. https://<name>.vault.azure.net/)."
  type        = string
}

# ---------------------------------------------------------------------------
# Secret content — written to Key Vault by this module
# ---------------------------------------------------------------------------

variable "env_config" {
  description = "Flat map of chart env var key-value pairs for the 'env' Key Vault secret."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "docker_username" {
  description = "Docker registry username for image pulls."
  type        = string
  sensitive   = true
  default     = null
}

variable "docker_password" {
  description = "Docker registry password for image pulls."
  type        = string
  sensitive   = true
  default     = null
}

variable "docker_registry_server" {
  description = "Docker registry server hostname."
  type        = string
  default     = "docker.io"
}

variable "docker_email" {
  description = "Docker registry email address."
  type        = string
  default     = null
}

variable "managed_sync_config" {
  description = "Managed-sync secret data to write to Key Vault. Null when managed sync is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

# ---------------------------------------------------------------------------
# DNS / Cloudflare
# ---------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token for NS record delegation. Leave empty or use the dummy value to skip Cloudflare records."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for NS delegation records."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# ArgoCD Helm
# ---------------------------------------------------------------------------

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD into."
  type        = string
  default     = "argocd"
}

variable "argocd_release_name" {
  description = "Argo CD Helm release name used for in-cluster secret discovery."
  type        = string
  default     = "argo-cd"
}

variable "argocd_version" {
  description = "Argo CD container image tag."
  type        = string
}

variable "argocd_helm_chart_version" {
  description = "Version of the argo-cd Helm chart."
  type        = string
}

variable "eso_chart_version" {
  description = "Helm chart version for external-secrets operator."
  type        = string
}

variable "destination_namespace" {
  description = "Target namespace for Paragon workloads."
  type        = string
  default     = "paragon"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for ExternalSecrets."
  type        = string
  default     = "azure-key-vault"
}

variable "bootstrap_repo_url" {
  description = "Git repository URL for App-of-Apps bootstrap."
  type        = string
  default     = ""
}

variable "bootstrap_repo_path" {
  description = "Path inside bootstrap_repo_url containing child Application manifests."
  type        = string
  default     = ""
}

variable "bootstrap_repo_revision" {
  description = "Git revision for App-of-Apps bootstrap."
  type        = string
  default     = "HEAD"
}

variable "bootstrap_repo_token" {
  description = "GitHub personal access token for cloning bootstrap_repo_url."
  type        = string
  sensitive   = true
  default     = null
}

variable "auto_sync" {
  description = "Whether to enable automatic sync on the bootstrap Application."
  type        = bool
  default     = true
}

variable "self_heal" {
  description = "Whether to enable self-healing on the bootstrap Application."
  type        = bool
  default     = true
}

variable "paragon_domain" {
  description = "Customer-facing Paragon domain."
  type        = string
  default     = ""
}

variable "app_chart_repository" {
  description = "Helm chart repository URL for Paragon application charts."
  type        = string
  default     = ""
}

variable "paragon_chart_version" {
  description = "Target chart version for Paragon charts."
  type        = string
  default     = null
}

variable "paragon_monitor_version" {
  description = "Chart version for the monitoring stack."
  type        = string
  default     = null
}

variable "paragon_managed_sync_version" {
  description = "Chart version for managed-sync."
  type        = string
  default     = null
}

variable "paragon_monitors_enabled" {
  description = "Whether monitoring charts are deployed via Argo CD."
  type        = bool
  default     = false
}

variable "managed_sync_enabled" {
  description = "Whether managed sync is enabled."
  type        = bool
  default     = false
}

variable "ingress_scheme" {
  description = "Ingress scheme for ArgoCD-managed ingress."
  type        = string
  default     = "internet-facing"
}

variable "argocd_addon_overrides" {
  description = "Optional overrides merged into the ArgoCD Helm values."
  type        = map(any)
  default     = {}
}
