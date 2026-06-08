variable "workspace" {
  description = "Workspace name used for resource naming."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for the cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
}

variable "labels" {
  description = "Labels to apply to GCP resources (must be lowercase key/value pairs)."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Secret content
# ---------------------------------------------------------------------------

variable "env_config" {
  description = "Flat map of environment variables written to the env Secret Manager secret."
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
  description = "Docker registry server (default docker.io)."
  type        = string
  default     = "docker.io"
}

variable "docker_email" {
  description = "Docker registry email (optional)."
  type        = string
  default     = null
}

variable "managed_sync_config" {
  description = "Optional managed-sync secret data (null when managed sync is disabled)."
  type        = map(string)
  sensitive   = true
  default     = null
}

# ---------------------------------------------------------------------------
# DNS / Cloudflare
# ---------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token for NS delegation. Empty string disables Cloudflare records."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for NS record delegation."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# ArgoCD tooling
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
  default     = "v3.4.2"
}

variable "argocd_helm_chart_version" {
  description = "Version of the argo-cd Helm chart."
  type        = string
  default     = "9.5.15"
}

variable "eso_chart_version" {
  description = "Helm chart version for external-secrets operator."
  type        = string
  default     = "0.14.4"
}

variable "destination_namespace" {
  description = "Target namespace for Paragon workloads."
  type        = string
  default     = "paragon"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for ExternalSecrets."
  type        = string
  default     = "gcp-secret-manager"
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
  description = "GitHub personal access token for cloning bootstrap_repo_url (HTTPS)."
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
  description = "Customer-facing Paragon domain (GitOps bridge annotation paragon_domain)."
  type        = string
  default     = ""
}

variable "app_chart_repository" {
  description = "Helm chart repository URL for Paragon application charts (GitOps bridge annotation)."
  type        = string
  default     = ""
}

variable "paragon_chart_version" {
  description = "Target chart version or constraint for Paragon charts (GitOps bridge annotation)."
  type        = string
  default     = null
}

variable "paragon_monitor_version" {
  description = "Chart version for the monitoring stack (GitOps bridge annotation)."
  type        = string
  default     = null
}

variable "paragon_managed_sync_version" {
  description = "Chart version for managed-sync (GitOps bridge annotation)."
  type        = string
  default     = null
}

variable "paragon_monitors_enabled" {
  description = "Whether monitoring charts are deployed via Argo CD (GitOps bridge annotation)."
  type        = bool
  default     = false
}

variable "managed_sync_enabled" {
  description = "Whether managed sync is enabled (GitOps bridge annotation)."
  type        = bool
  default     = false
}

variable "ingress_scheme" {
  description = "GKE Gateway ingress scheme for Argo CD-managed ingress (GitOps bridge annotation)."
  type        = string
  default     = "external"
}

variable "argocd_addon_overrides" {
  description = "Optional overrides merged into the ArgoCD Helm values."
  type        = map(any)
  default     = {}
}
