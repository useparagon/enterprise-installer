variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
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
  description = "AWS region for the Secrets Manager resources."
  type        = string
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the cluster-autoscaler service account (from the cluster module)."
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD into."
  type        = string
  default     = "argocd"
}

variable "create_gp3_storage_class" {
  description = "Create a default gp3 StorageClass. Leave false when upgrading from SSM bootstrap (gp3 already exists)."
  type        = bool
  default     = false
}

variable "argocd_release_name" {
  description = "Argo CD Helm release name used for in-cluster secret discovery."
  type        = string
  default     = "argo-cd"
}

variable "eso_role_arn" {
  description = "IAM role ARN for the External Secrets Operator service account (installed via Blueprints)."
  type        = string
}

variable "eso_crds_ready" {
  description = "Set when Blueprints ESO Helm + CRD wait have completed (time_sleep id from parent module)."
  type        = string
}

variable "secrets_manager_secret_arns" {
  description = "List of Secrets Manager secret ARNs that ESO should be allowed to read."
  type        = list(string)
  default     = []
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
  description = "GitHub personal access token for cloning bootstrap_repo_url (HTTPS). Set via Spacelift context / TF_VAR_* (never commit). Needs repo read on the bootstrap repository."
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

variable "paragon_certificate_arn" {
  description = "ACM certificate ARN for Paragon ALB ingress (wildcard for paragon_domain). Exposed on the in-cluster GitOps bridge secret for ApplicationSet helm values."
  type        = string
  default     = ""
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
  description = "Chart version for the monitoring stack when deployed via Argo CD (GitOps bridge annotation)."
  type        = string
  default     = null
}

variable "paragon_managed_sync_version" {
  description = "Chart version for managed-sync when deployed via Argo CD (GitOps bridge annotation)."
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
  description = "ALB scheme for Argo CD-managed ingress (GitOps bridge annotation)."
  type        = string
  default     = "internet-facing"
}

variable "app_of_apps_manifest" {
  description = "Deprecated override for root Argo CD Application YAML."
  type        = string
  default     = null
}
