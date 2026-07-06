# ---------------------------------------------------------------------------
# AWS credentials
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key for AWS account to provision resources on."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for AWS account to provision resources on."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_session_token" {
  description = "AWS session token."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_assume_role_arn" {
  description = "Optional IAM role ARN to assume (e.g. customer Terraform role when running from Spacelift backend account)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Account
# ---------------------------------------------------------------------------

variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "az_count" {
  description = "Number of AZs to cover in a given region."
  type        = number
  default     = 2
  nullable    = false
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "vpc_cidr_newbits" {
  description = "Newbits used for calculating subnets."
  type        = number
  default     = 3
  nullable    = false
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

variable "rds_instance_class" {
  description = "The RDS instance class type used for Postgres."
  type        = string
  default     = "db.t4g.small"
  nullable    = false
}

variable "rds_postgres_version" {
  description = "Postgres version for the database."
  type        = string
  default     = "16"
  nullable    = false
}

variable "rds_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
  nullable    = false
}

variable "rds_multi_az" {
  description = "Whether or not to enable multi-AZ in each RDS instance."
  type        = bool
  default     = true
  nullable    = false
}

variable "rds_restore_from_snapshot" {
  description = "Specifies that RDS instances should be restored from a snapshot."
  type        = bool
  default     = false
  nullable    = false
}

variable "rds_final_snapshot_enabled" {
  description = "Specifies that RDS instances should perform a final snapshot before being deleted."
  type        = bool
  default     = true
  nullable    = false
}

variable "rds_gp3_iops" {
  description = "gp3 IOPS for Postgres; null uses size-based baseline (3000 below 400 GiB, 12000 at/above). Set with rds_gp3_storage_throughput to override; only valid when rds_allocated_storage >= 400 GiB."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.rds_gp3_iops == null || var.rds_allocated_storage >= 400
    error_message = "rds_gp3_iops can only be set when rds_allocated_storage is >= 400 GiB (PostgreSQL gp3 minimum at that size is 12000)."
  }
}

variable "rds_gp3_storage_throughput" {
  description = "gp3 throughput (MiB/s); null uses size-based baseline (125 below 400 GiB, 500 at/above). Use a valid pair with rds_gp3_iops when overriding."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition = var.rds_gp3_iops == null || var.rds_gp3_storage_throughput == null || (
      var.rds_allocated_storage < 400 || (
        coalesce(var.rds_gp3_iops, 12000) >= 12000 && coalesce(var.rds_gp3_storage_throughput, 500) >= 500
      )
    )
    error_message = "For rds_allocated_storage >= 400 GiB, gp3 requires at least 12000 IOPS and 500 MiB/s throughput."
  }
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage (GiB) for each Postgres RDS instance."
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage (GiB) for autoscaling on each Postgres RDS instance."
  type        = number
  default     = 1000
}

# ---------------------------------------------------------------------------
# ElastiCache
# ---------------------------------------------------------------------------

variable "elasticache_node_type" {
  description = "The ElastiCache node type used for Redis."
  type        = string
  default     = "cache.r6g.large"
  nullable    = false
}

variable "elasticache_multiple_instances" {
  description = "Whether or not to create multiple ElastiCache instances. Used for higher volume installations."
  type        = bool
  default     = true
  nullable    = false
}

variable "elasticache_multi_az" {
  description = "Whether or not to enable multi-AZ in each ElastiCache instance."
  type        = bool
  default     = true
  nullable    = false
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.35"
  nullable    = false
}

variable "eks_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes nodes."
  type        = string
  default     = "m6a.xlarge"
  nullable    = false
}

variable "eks_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "t3a.xlarge,t3.xlarge,m5a.xlarge,m5.xlarge,m6a.xlarge,m6i.xlarge,m7a.xlarge,m7i.xlarge,r5a.xlarge,m4.xlarge"
  nullable    = false
}

variable "eks_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 75
  nullable    = false
  validation {
    condition     = var.eks_spot_instance_percent >= 0 && var.eks_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "eks_min_node_count" {
  description = "The minimum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 2
  nullable    = false
}

variable "eks_max_node_count" {
  description = "The maximum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 50
  nullable    = false
}

variable "eks_admin_arns" {
  description = "Array of ARNs for IAM users or roles that should have admin access to cluster. Used for viewing cluster resources in AWS dashboard."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "create_autoscaling_linked_role" {
  description = "Whether or not to create an IAM role for autoscaling."
  type        = bool
  default     = true
  nullable    = false
}

# ---------------------------------------------------------------------------
# MSK (Kafka)
# ---------------------------------------------------------------------------

variable "msk_kafka_version" {
  description = "The Kafka version for the MSK cluster."
  type        = string
  // NOTE: to use a small instance type like `kafka.t3.small`, we need to use an older version that uses zookeeper
  // we're default to an older version to keep costs low, but we can override this if we use a supported larger instance type
  default  = "3.6.0"
  nullable = false
}

variable "msk_kafka_num_broker_nodes" {
  description = "The number of broker nodes for the MSK cluster."
  type        = number
  default     = 2
  nullable    = false
}

variable "msk_autoscaling_enabled" {
  description = "Whether to enable autoscaling for the MSK cluster."
  type        = bool
  default     = true
  nullable    = false
}

variable "msk_instance_type" {
  description = "The instance type for the MSK cluster."
  type        = string
  default     = "kafka.t3.small"
  nullable    = false
}

# ---------------------------------------------------------------------------
# Security & storage
# ---------------------------------------------------------------------------

variable "master_guardduty_account_id" {
  description = "Optional AWS account id to delegate GuardDuty control to."
  type        = string
  default     = null
}

variable "mfa_enabled" {
  description = "Whether to require MFA for certain configurations (e.g. cloudtrail s3 bucket deletion)"
  type        = bool
  default     = false
  nullable    = false
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist ssh access."
  type        = string
  default     = ""
  nullable    = false
}

variable "disable_cloudtrail" {
  description = "Used to specify that Cloudtrail is disabled."
  type        = bool
  default     = true
  nullable    = false
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
  default     = false
  nullable    = false
}

variable "app_bucket_expiration" {
  description = "The number of days to retain S3 app data before deleting"
  type        = number
  default     = 90
  nullable    = false
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
  default     = 365
  nullable    = false
}

variable "auditlogs_lock_enabled" {
  description = "Whether to enable S3 Object Lock for the audit logs bucket."
  type        = bool
  default     = false
  nullable    = false
}

variable "cdn_bucket_acl_reset" {
  description = "Reset the CDN S3 bucket ACL to private before BucketOwnerEnforced. Defaults to false; set true once when migrating a legacy CDN bucket with existing ACL grants, then remove."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Cloudflare
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Feature flags
# ---------------------------------------------------------------------------

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
  default     = false
  nullable    = false
}

variable "argocd_enabled" {
  description = "Enable ArgoCD-based GitOps deployment. When true, bootstraps ArgoCD and ESO on the cluster, writes config to Secrets Manager, and applies ArgoCD Application manifests."
  type        = bool
  default     = false
  nullable    = false
}

variable "k8s_providers_enabled" {
  description = "Configure kubernetes/helm/kubectl providers against the EKS API. Defaults to false; set true when destroying a stack that still has GitOps resources in state while argocd_enabled is false."
  type        = bool
  default     = false
  nullable    = false
}

# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------

variable "migrated_workspace" {
  description = "Override the workspace name to preserve naming conventions when migrating from legacy workspaces"
  type        = string
  default     = null
}

variable "migrated_passwords" {
  description = "Override credentials to preserve complexity conventions when migrating from legacy workspaces"
  type        = map(string)
  default     = {}
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
  description = "Optional Helm set overrides for the Argo CD release."
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

variable "eso_addon_overrides" {
  description = "Optional values merged into the external-secrets Helm release values map."
  type        = map(any)
  default     = {}
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
  description = "Helm chart repository URL for Paragon application charts (e.g. OCI registry or HTTPS repo)."
  type        = string
  default     = "https://paragon-helm-production.s3.amazonaws.com"
  nullable    = false
}

variable "argocd_bootstrap_repo_url" {
  description = "HTTPS Git repository URL for Argo CD App-of-Apps bootstrap (e.g. https://github.com/org/repo.git). Leave empty to skip creating the root Application."
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
  description = "GitHub PAT for argocd_bootstrap_repo_url (HTTPS). Set via Spacelift context / TF_VAR_* (never commit). Required when bootstrap repo URL and path are set."
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
  description = "Optional managed-sync secret data to write to Secrets Manager. Null when managed sync is disabled."
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
  description = "Customer-facing Paragon domain (e.g. customer.example.com). Used for ACM/ingress and written to Secrets Manager as PARAGON_DOMAIN and derived *_PUBLIC_URL values when argocd_enabled."
  type        = string
  default     = null
}

variable "argocd_env_overrides" {
  description = "Optional overrides for any infra-derived env key written to Secrets Manager (e.g. ACCOUNT_PUBLIC_URL, CERBERUS_POSTGRES_PORT, CLOUD_STORAGE_PUBLIC_BUCKET). Merged on top of computed defaults; argocd_app_secrets wins if the same key is set in both."
  type        = map(string)
  default     = null
}

variable "argocd_app_secrets" {
  description = "Customer-provided secret env vars (LICENSE, OAuth client secrets, SMTP, etc.) merged into the flat paragon/env Secrets Manager secret last. Overrides argocd_env_overrides when the same key is set in both."
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

variable "secrets_recovery_window_in_days" {
  description = "Secrets Manager deletion recovery window for application secrets (env, docker-cfg, managed-sync, openobserve) and runtime handoff secrets. Set to 0 for immediate deletion so names are free after destroy; use 7–30 in production for undo protection."
  type        = number
  default     = 0

  validation {
    condition     = var.secrets_recovery_window_in_days == 0 || (var.secrets_recovery_window_in_days >= 7 && var.secrets_recovery_window_in_days <= 30)
    error_message = "secrets_recovery_window_in_days must be 0 (immediate) or between 7 and 30."
  }
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — ingress
# ---------------------------------------------------------------------------

variable "argocd_ingress_scheme" {
  description = "ALB scheme for ArgoCD-managed ingress: internet-facing or internal."
  type        = string
  default     = "internet-facing"
  nullable    = false
}

variable "argocd_certificate_arn" {
  description = "ACM certificate ARN for the ArgoCD-managed ingress."
  type        = string
  default     = ""
  nullable    = false
}

variable "paragon_certificate_arn" {
  description = "ACM certificate ARN for Paragon microservice ALB ingress (wildcard for paragon_domain). When empty and argocd_enabled, Terraform requests a new ACM cert and delegates DNS to Route 53 (NS records in Cloudflare when cloudflare_tunnel_zone_id is set)."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = trimspace(var.paragon_certificate_arn) == "" || startswith(trimspace(var.paragon_certificate_arn), "arn:aws:acm:")
    error_message = "paragon_certificate_arn must be an ACM certificate ARN when provided."
  }
}

variable "gitops_alb_ingressclass_exists" {
  description = "Brownfield flag: set true when a cluster-scoped IngressClass named \"alb\" already exists (e.g. installed by the legacy paragon Helm \"ingress\" release). When true, the AWS Load Balancer Controller is configured with createIngressClassResource=false to avoid an \"already exists\" conflict. Set explicitly per stack instead of probed at plan time — a live cluster read during plan blocks the entire plan (and any destroy) for minutes whenever the EKS API is unreachable."
  type        = bool
  default     = false
  nullable    = false
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  hash        = substr(sha256(data.aws_caller_identity.current.account_id), 0, 8)
  environment = "enterprise"
  workspace   = coalesce(var.migrated_workspace, "paragon-${var.organization}-${local.hash}")

  paragon_domain_trimmed = var.paragon_domain != null ? trimspace(var.paragon_domain) : ""

  default_tags = merge(
    {
      Name        = "paragon-${var.organization}"
      Environment = local.environment
      Creator     = "Terraform"
    },
    trimspace(var.organization) == "" ? {} : { Organization = var.organization }
  )

  # get distinct values from comma-separated list, filter empty values and trim them
  # for `ip_whitelist`, if an ip doesn't contain a range at the end (e.g. `<IP_ADDRESS>/32`), then add `/32` to the end. `1.1.1.1` becomes `1.1.1.1/32`; `2.2.2.2/24` remains unchanged
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])

  eks_ondemand_node_instance_type = distinct([for value in split(",", var.eks_ondemand_node_instance_type) : trimspace(value)])
  eks_spot_node_instance_type     = distinct([for value in split(",", var.eks_spot_node_instance_type) : trimspace(value)])

  # Application secrets guard — domain and Docker creds required for a complete
  # GitOps bundle (paragon-secrets + docker-cfg ExternalSecrets).
  app_secrets_ready = (
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
      condition     = contains(["internet-facing", "internal"], var.argocd_ingress_scheme)
      error_message = "argocd_ingress_scheme must be either 'internet-facing' or 'internal'."
    }
    # Without docker creds + domain, ExternalSecrets for paragon-secrets/docker-cfg
    # cannot be wired while Argo CD and ESO still bootstrap.
    precondition {
      condition     = local.app_secrets_ready
      error_message = "argocd_enabled requires paragon_domain, argocd_docker_username, and argocd_docker_password so the paragon-secrets and docker-cfg secrets can be created for GitOps/ESO."
    }
    precondition {
      condition     = var.argocd_certificate_arn == "" || startswith(var.argocd_certificate_arn, "arn:aws:acm:")
      error_message = "argocd_certificate_arn must be an ACM certificate ARN when provided."
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
      error_message = "argocd_bootstrap_repo_url must use HTTPS (https://github.com/...). SSH git@ URLs are not supported; use argocd_bootstrap_repo_token for private repositories."
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
