# credentials
variable "gcp_credential_json_file" {
  description = "The path to the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided."
  type        = string
  default     = null
}

variable "gcp_project_id" {
  description = "The id of the Google Cloud Project. Required if not using `gcp_credential_json_file`."
  type        = string
  default     = null
}

variable "gcp_private_key_id" {
  description = "The id of the private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_private_key" {
  description = "The private key for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_email" {
  description = "The client email for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_id" {
  description = "The client id for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_client_x509_cert_url" {
  description = "The client certificate url for the service account. Required if not using `gcp_credential_json_file`."
  type        = string
  sensitive   = true
  default     = null
}

variable "gcp_assume_role" {
  description = "Whether to assume a role for the service account instead of using JSON credentials."
  type        = bool
  default     = false
  nullable    = false
}

# account
variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string

  validation {
    condition     = length(var.organization) <= 16
    error_message = "The `organization` input must be 16 or less characters."
  }
}

variable "environment" {
  description = "Type of environment being deployed to."
  type        = string
  default     = "enterprise"
  nullable    = false
}

variable "vpc_cidr" {
  description = "CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone" {
  description = "The zone in the region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone_backup" {
  description = "The backup zone in the region where to host Google Cloud Organization resources."
  type        = string
}

# bastion
variable "bastion_enabled" {
  description = "Whether to create the bastion host and its associated Cloudflare tunnel."
  type        = bool
  default     = true
}

# cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS`"
  type        = string
  sensitive   = true
  default     = "dummy-cloudflare-tokens-must-be-40-chars"
  nullable    = false
}

variable "cloudflare_tunnel_enabled" {
  description = "Flag whether to enable Cloudflare Zero Trust tunnel for bastion"
  type        = bool
  default     = false
  nullable    = false
}

variable "cloudflare_tunnel_subdomain" {
  description = "Subdomain under the Cloudflare Zone to create the tunnel"
  type        = string
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_zone_id" {
  description = "Zone ID for Cloudflare domain"
  type        = string
  sensitive   = true
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_account_id" {
  description = "Account ID for Cloudflare account"
  type        = string
  sensitive   = true
  default     = ""
  nullable    = false
}

variable "cloudflare_tunnel_email_domain" {
  description = "Email domain for Cloudflare access"
  type        = string
  sensitive   = true
  default     = "useparagon.com"
  nullable    = false
}

# optional network restrictions
variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist ssh access."
  type        = string
  default     = ""
  nullable    = false
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on database and storage resources."
  type        = bool
  default     = false
  nullable    = false
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
  default     = 365
  nullable    = false
}

variable "auditlogs_lock_enabled" {
  description = "Whether to lock the GCS audit logs bucket retention policy."
  type        = bool
  default     = false
  nullable    = false
}

# postgres
variable "postgres_tier" {
  description = "The instance type to use for Postgres."
  type        = string
  default     = "db-custom-2-7680"
  nullable    = false
  # https://cloud.google.com/sql/docs/mysql/instance-settings#:~:text=see%20Instance%20Locations.-,Machine,-Type
}

variable "postgres_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
  nullable    = false
}

# redis
variable "redis_multiple_instances" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
  default     = true
  nullable    = false
}

variable "redis_memory_size" {
  description = "The size of the Redis instance (in GB)."
  type        = number
  default     = 2
  nullable    = false
}

# managed sync (GMK = Google Managed Kafka)
variable "managed_sync_enabled" {
  description = "Whether to enable managed sync (GMK cluster, managed_sync bucket, postgres and redis instances)."
  type        = bool
  default     = false
  nullable    = false
}

variable "gmk_kafka_version" {
  description = "Kafka version for the Google Managed Kafka cluster (version offered by the service)."
  type        = string
  default     = "3.7.1"
  nullable    = false
}

variable "gmk_vcpu_count" {
  description = "Number of vCPUs for the GMK cluster (minimum 3 in GCP)."
  type        = number
  default     = 3
  nullable    = false
}

variable "gmk_memory_gib" {
  description = "Memory in GiB for the GMK cluster (1-8 GiB per vCPU)."
  type        = number
  default     = 6
  nullable    = false
}

variable "gmk_disk_size_gib" {
  description = "Disk size in GiB per broker for the GMK cluster."
  type        = number
  default     = 100
  nullable    = false
}

variable "gmk_auto_rebalance" {
  description = "Whether to enable automatic partition rebalancing across brokers (can add load)."
  type        = bool
  default     = false
  nullable    = false
}

variable "gmk_sasl_mechanism" {
  description = "SASL mechanism: plain (module creates SA key and outputs in kafka.cluster_password) or oauthbearer (Workload Identity)."
  type        = string
  default     = "plain"
  nullable    = false

  validation {
    condition     = contains(["oauthbearer", "plain"], var.gmk_sasl_mechanism)
    error_message = "gmk_sasl_mechanism must be \"oauthbearer\" or \"plain\"."
  }
}

variable "gmk_sasl_plain_key_file_path" {
  description = "Optional path to your own Kafka SA key JSON for SASL/PLAIN. When empty, the module creates the key and outputs it in kafka.cluster_password."
  type        = string
  default     = ""
  nullable    = false
}

# kubernetes
variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.34"
  nullable    = false
}

variable "k8s_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
  default     = 2
  nullable    = false
}

variable "k8s_max_node_count" {
  description = "Maximum number of node Kubernetes can scale up to."
  type        = number
  default     = 50
  nullable    = false
}

variable "k8s_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 80
  nullable    = false
  validation {
    condition     = var.k8s_spot_instance_percent >= 0 && var.k8s_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
  default     = "e2-standard-4"
  nullable    = false
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "e2-standard-4"
  nullable    = false
}

variable "k8s_disable_public_endpoint" {
  description = "Used to disable public endpoint on GKE cluster."
  type        = bool
  default     = true
  nullable    = false
}

variable "k8s_master_authorized_networks" {
  description = "List of CIDRs allowed to reach the GKE control plane (Master Authorized Networks). Use [{ cidr_block = \"0.0.0.0/0\", display_name = \"all\" }] to allow all IPs (e.g. from any country). Empty list = only cluster nodes (restricted)."
  type = list(object({
    cidr_block   = string
    display_name = optional(string, "")
  }))
  default  = []
  nullable = false
}

variable "use_storage_account_key" {
  description = "Whether to use the storage service account privatekey for the storage service account."
  type        = bool
  default     = false
  nullable    = false
}

variable "tfc_agent_token" {
  description = "Terraform Cloud Agent token to support Terraform runs from the bastion"
  type        = string
  sensitive   = true
  default     = ""
  nullable    = false
}

locals {
  creds_json     = try(jsondecode(file(var.gcp_credential_json_file)), {})
  gcp_project_id = try(local.creds_json.project_id, var.gcp_project_id)

  gcp_creds = jsonencode({
    type                        = "service_account",
    auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs",
    auth_uri                    = "https://accounts.google.com/o/oauth2/auth",
    token_uri                   = "https://oauth2.googleapis.com/token",
    client_email                = try(local.creds_json.client_email, var.gcp_client_email),
    client_id                   = try(local.creds_json.client_id, var.gcp_client_id),
    client_x509_cert_url        = try(local.creds_json.client_x509_cert_url, var.gcp_client_x509_cert_url),
    gcp_project_id              = try(local.creds_json.gcp_project_id, var.gcp_project_id),
    private_key                 = try(local.creds_json.private_key, var.gcp_private_key),
    private_key_id              = try(local.creds_json.private_key_id, var.gcp_private_key_id),
  })

  # hash of project ID to help ensure uniqueness of resources like bucket names
  # coalesce so tflint/validate can run when gcp_project_id is not set (e.g. no tfvars)
  hash      = substr(sha256(coalesce(local.gcp_project_id, "tflint")), 0, 8)
  workspace = nonsensitive("paragon-${var.organization}-${local.hash}")

  default_labels = {
    name         = local.workspace
    environment  = var.environment
    organization = var.organization
    creator      = "terraform"
  }

  // get distinct values from comma-separated list, filter empty values and trim them
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])
}
# ArgoCD / GitOps variables and locals for GCP infra workspace.

variable "argocd_enabled" {
  description = "Enable ArgoCD-based GitOps deployment. When true, bootstraps ArgoCD and ESO on the cluster, writes config to Secret Manager, and applies ArgoCD Application manifests."
  type        = bool
  default     = false
  nullable    = false
}

variable "k8s_providers_enabled" {
  description = "Configure kubernetes/helm/kubectl providers against the GKE API. Defaults to false; set true when destroying a stack that still has GitOps resources in state while argocd_enabled is false."
  type        = bool
  default     = false
  nullable    = false
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — tooling
# ---------------------------------------------------------------------------

variable "argocd_version" {
  description = "Argo CD container image tag (e.g. v3.4.2). Applied via the official argo-cd Helm chart."
  type        = string
  default     = "v3.4.2"
  nullable    = false
}

variable "argocd_helm_chart_version" {
  description = "Version of the argo-cd Helm chart from https://argoproj.github.io/argo-helm."
  type        = string
  default     = "9.5.15"
  nullable    = false
}

variable "argocd_addon_overrides" {
  description = "Optional overrides merged into the ArgoCD Helm values."
  type        = map(any)
  default     = {}
  nullable    = false
}

variable "eso_chart_version" {
  description = "Helm chart version for external-secrets operator."
  type        = string
  default     = "0.14.4"
  nullable    = false
}

variable "argocd_auto_sync" {
  description = "Whether ArgoCD Applications should auto-sync on git/chart changes."
  type        = bool
  default     = true
  nullable    = false
}

variable "argocd_self_heal" {
  description = "Whether ArgoCD should auto-correct drift from desired state."
  type        = bool
  default     = true
  nullable    = false
}

variable "argocd_slack_token" {
  description = "Optional Slack bot token for ArgoCD sync notifications."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_slack_channel" {
  description = "Slack channel name for ArgoCD notifications."
  type        = string
  default     = ""
  nullable    = false
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — Paragon application charts
# ---------------------------------------------------------------------------

variable "argocd_app_chart_repository" {
  description = "Helm chart repository URL for Paragon application charts."
  type        = string
  default     = "https://paragon-helm-production.s3.amazonaws.com"
  nullable    = false
}

variable "argocd_bootstrap_repo_url" {
  description = "HTTPS Git repository URL for Argo CD App-of-Apps bootstrap. Leave empty to skip."
  type        = string
  default     = ""
  nullable    = false
}

variable "argocd_bootstrap_repo_path" {
  description = "Path inside argocd_bootstrap_repo_url containing child Application manifests."
  type        = string
  default     = ""
  nullable    = false
}

variable "argocd_bootstrap_repo_revision" {
  description = "Git revision (branch, tag, or commit) for App-of-Apps bootstrap."
  type        = string
  default     = "HEAD"
  nullable    = false
}

variable "argocd_bootstrap_repo_token" {
  description = "GitHub PAT for argocd_bootstrap_repo_url (HTTPS). Set via Spacelift context / TF_VAR_* (never commit)."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_bootstrap_repo_private" {
  description = "When true, argocd_bootstrap_repo_token is required to clone the bootstrap repository."
  type        = bool
  default     = false
  nullable    = false
}

variable "paragon_monitors_enabled" {
  description = "Whether monitoring charts should be deployed via ArgoCD."
  type        = bool
  default     = false
  nullable    = false
}

variable "paragon_managed_sync_config" {
  description = "Optional managed-sync secret data to write to Secret Manager. Null when managed sync is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "paragon_managed_sync_version" {
  description = "Chart version for managed-sync when deployed via ArgoCD. Required when argocd_enabled and managed_sync_enabled are both true."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — application secrets
# ---------------------------------------------------------------------------

variable "paragon_domain" {
  description = "Customer-facing Paragon domain (e.g. customer.example.com). Written to Secret Manager as PARAGON_DOMAIN and derived *_PUBLIC_URL values when argocd_enabled."
  type        = string
  default     = null
}

variable "argocd_env_overrides" {
  description = "Optional overrides for any infra-derived env key written to Secret Manager. Merged on top of computed defaults."
  type        = map(string)
  default     = null
}

variable "argocd_app_secrets" {
  description = "Customer-provided secret env vars (LICENSE, OAuth, SMTP, etc.) merged last into the flat env secret."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "argocd_docker_registry_server" {
  description = "Docker registry server for ArgoCD image pulls."
  type        = string
  default     = "docker.io"
  nullable    = false
}

variable "argocd_docker_username" {
  description = "Docker username for ArgoCD image pulls."
  type        = string
  default     = null
}

variable "argocd_docker_password" {
  description = "Docker password for ArgoCD image pulls."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_docker_email" {
  description = "Docker email for ArgoCD image pulls."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — ingress
# ---------------------------------------------------------------------------

variable "argocd_ingress_scheme" {
  description = "GKE Gateway ingress scheme: external or internal."
  type        = string
  default     = "external"
  nullable    = false

  validation {
    condition     = contains(["external", "internal"], var.argocd_ingress_scheme)
    error_message = "argocd_ingress_scheme must be either 'external' or 'internal'."
  }
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  paragon_domain_trimmed = var.paragon_domain != null ? trimspace(var.paragon_domain) : ""

  # argocd_secrets_ready is used only for validate_argocd_versions precondition.
  argocd_secrets_ready = (
    local.argocd_domain != "" &&
    var.argocd_docker_username != null &&
    var.argocd_docker_password != null
  )
}

resource "terraform_data" "validate_argocd_versions" {
  count = var.argocd_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.argocd_app_chart_repository) != ""
      error_message = "argocd_app_chart_repository cannot be empty."
    }
    precondition {
      condition     = var.paragon_managed_sync_version == null || trimspace(var.paragon_managed_sync_version) != ""
      error_message = "paragon_managed_sync_version cannot be empty when set."
    }
    precondition {
      condition = (
        !var.argocd_enabled ||
        !var.managed_sync_enabled ||
        (var.paragon_managed_sync_version != null && trimspace(var.paragon_managed_sync_version) != "")
      )
      error_message = "paragon_managed_sync_version is required when argocd_enabled and managed_sync_enabled are both true."
    }
    precondition {
      condition = (
        !var.argocd_enabled ||
        !var.managed_sync_enabled ||
        (var.paragon_managed_sync_config != null && length(var.paragon_managed_sync_config) > 0)
      )
      error_message = "paragon_managed_sync_config is required when argocd_enabled and managed_sync_enabled are both true."
    }
    precondition {
      condition     = contains(["external", "internal"], var.argocd_ingress_scheme)
      error_message = "argocd_ingress_scheme must be either 'external' or 'internal'."
    }
    precondition {
      condition     = local.argocd_secrets_ready
      error_message = "argocd_enabled requires paragon_domain, argocd_docker_username, and argocd_docker_password so the paragon-secrets and docker-cfg secrets can be created for GitOps/ESO."
    }
    precondition {
      condition     = var.argocd_slack_token == null || trimspace(var.argocd_slack_channel) != ""
      error_message = "argocd_slack_channel must be set when argocd_slack_token is provided."
    }
    precondition {
      condition     = trimspace(var.argocd_slack_channel) == "" || var.argocd_slack_token != null
      error_message = "argocd_slack_token must be set when argocd_slack_channel is provided."
    }
    precondition {
      condition = (
        (trimspace(var.argocd_bootstrap_repo_url) == "" && trimspace(var.argocd_bootstrap_repo_path) == "") ||
        (trimspace(var.argocd_bootstrap_repo_url) != "" && trimspace(var.argocd_bootstrap_repo_path) != "")
      )
      error_message = "argocd_bootstrap_repo_url and argocd_bootstrap_repo_path must either both be empty or both be set."
    }
    precondition {
      condition = (
        trimspace(var.argocd_bootstrap_repo_url) == "" ||
        trimspace(var.argocd_bootstrap_repo_path) == "" ||
        startswith(trimspace(var.argocd_bootstrap_repo_url), "https://")
      )
      error_message = "argocd_bootstrap_repo_url must use HTTPS (https://github.com/...). SSH git@ URLs are not supported."
    }
    precondition {
      condition = (
        trimspace(var.argocd_bootstrap_repo_url) == "" ||
        trimspace(var.argocd_bootstrap_repo_path) == "" ||
        !var.argocd_bootstrap_repo_private ||
        (
          var.argocd_bootstrap_repo_token != null &&
          trimspace(var.argocd_bootstrap_repo_token) != ""
        )
      )
      error_message = "argocd_bootstrap_repo_token is required when argocd_bootstrap_repo_private is true and bootstrap repo URL/path are set."
    }
    precondition {
      condition = (
        !var.argocd_enabled ||
        (var.paragon_domain != null && trimspace(var.paragon_domain) != "")
      )
      error_message = "paragon_domain must be set when argocd_enabled is true."
    }
  }
}

