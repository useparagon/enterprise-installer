variable "argocd_enabled" {
  description = "When false, no ArgoCD/GitOps resources are created in this module."
  type        = bool
  default     = false
  nullable    = false
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_autoscaler_enabled" {
  description = "Deploy cluster-autoscaler via Argo CD when legacy managed node groups are active."
  type        = bool
  default     = false
  nullable    = false
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster."
  type        = string
}

variable "oidc_issuer_url" {
  description = "URL of the OIDC issuer for the EKS cluster."
  type        = string
}

variable "workspace" {
  description = "Workspace name used for resource naming."
  type        = string
}

variable "aws_region" {
  description = "AWS region for Secrets Manager and Route 53 resources."
  type        = string
}

# ---------------------------------------------------------------------------
# Application secrets — created by the root secrets module
# ---------------------------------------------------------------------------

variable "secrets_manager_secret_arns" {
  description = "ARNs of application Secrets Manager secrets the ESO role may read."
  type        = list(string)
  default     = []
}

variable "env_secret_name" {
  description = "Secrets Manager secret name for environment config."
  type        = string
  default     = null
}

variable "docker_cfg_secret_name" {
  description = "Secrets Manager secret name for Docker credentials."
  type        = string
  default     = null
}

variable "managed_sync_secret_name" {
  description = "Secrets Manager secret name for managed sync config (null if disabled)."
  type        = string
  default     = null
}

variable "openobserve_secret_name" {
  description = "Secrets Manager secret name for OpenObserve credentials (null if not created)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# DNS / Cloudflare / TLS
# ---------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token for NS record delegation. Leave empty or use the dummy value to skip Cloudflare records."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for paragon_domain NS delegation."
  type        = string
  default     = ""
}

variable "paragon_certificate_arn" {
  description = "Existing ACM certificate ARN for Paragon ALB ingress. When empty, Terraform requests a new ACM cert in the paragon_domain Route 53 zone."
  type        = string
  default     = ""
}

variable "gitops_alb_ingressclass_exists" {
  description = "Brownfield flag: set true when a cluster-scoped IngressClass named alb already exists."
  type        = bool
  default     = false
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
  description = "Argo CD Helm release name."
  type        = string
  default     = "argo-cd"
}

variable "argocd_version" {
  description = "Argo CD container image tag."
  type        = string
}

variable "argocd_helm_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
}

variable "argocd_addon_overrides" {
  description = "Optional Helm set overrides for the Argo CD release (name = set path, value = set value)."
  type        = map(any)
  default     = {}
  nullable    = false
}

variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version."
  type        = string
}

variable "eso_addon_overrides" {
  description = "Optional values merged into the external-secrets Helm release values map."
  type        = map(any)
  default     = {}
  nullable    = false
}

variable "create_gp3_storage_class" {
  description = "Create a default gp3 StorageClass. Leave false when upgrading from SSM bootstrap (gp3 already exists)."
  type        = bool
  default     = false
}

variable "destination_namespace" {
  description = "Target namespace for Paragon workloads."
  type        = string
  default     = "paragon"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for ExternalSecrets."
  type        = string
  default     = "aws-secrets-manager"
}

# ---------------------------------------------------------------------------
# Bootstrap repo
# ---------------------------------------------------------------------------

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
  description = "GitHub PAT for bootstrap_repo_url (HTTPS)."
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

# ---------------------------------------------------------------------------
# Paragon application
# ---------------------------------------------------------------------------

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

variable "paragon_managed_sync_version" {
  description = "Chart version for managed-sync when deployed via Argo CD."
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
  description = "ALB scheme for Argo CD-managed ingress."
  type        = string
  default     = "internet-facing"
}

variable "app_of_apps_manifest" {
  description = "Deprecated override for root Argo CD Application YAML."
  type        = string
  default     = null
}
