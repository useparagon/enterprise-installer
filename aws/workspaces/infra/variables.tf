# credentials
variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key for AWS account to provision resources on. Null when using ambient credentials (Spacelift AWS integration) with aws_assume_role_arn."
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for AWS account to provision resources on. Null when using ambient credentials (Spacelift AWS integration) with aws_assume_role_arn."
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
  description = "Optional IAM role ARN to assume (e.g. customer Terraform role when running from Spacelift)."
  type        = string
  default     = null
}

# account
variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string

  validation {
    condition     = length(var.organization) <= 16
    error_message = "organization must be at most 16 characters so paragon-{organization}-{hash} can fit the 28-character workspace limit."
  }
}

# network
variable "az_count" {
  description = "Number of AZs to cover in a given region."
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_newbits" {
  description = "Newbits used for calculating subnets."
  type        = number
  default     = 3
}

# rds
variable "rds_instance_class" {
  description = "The RDS instance class type used for Postgres."
  type        = string
  default     = "db.t4g.small"
}

variable "rds_managed_sync_instance_class" {
  description = "The RDS instance class type used for the managed sync Postgres instance."
  type        = string
  default     = "db.t4g.small"
}

variable "rds_postgres_version" {
  description = "Postgres version for the database."
  type        = string
  default     = "14"
}

variable "rds_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  description = "Whether or not to enable multi-AZ in each RDS instance."
  type        = bool
  default     = true
}

variable "rds_restore_from_snapshot" {
  description = "Specifies that RDS instances should be restored from a snapshot."
  type        = bool
  default     = false
}

variable "rds_final_snapshot_enabled" {
  description = "Specifies that RDS instances should perform a final snapshot before being deleted."
  type        = bool
  default     = true
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

# elasticache
variable "elasticache_node_type" {
  description = "ElastiCache node type for legacy Redis OSS only. Valkey sizing lives in valkey_instances."
  type        = string
  default     = "cache.r6g.large"
}

variable "elasticache_multiple_instances" {
  description = "ElastiCache topology for Valkey (and legacy Redis while redis_enabled). When true, separate cache (cluster), queue, system, and managed_sync instances; when false, one shared cache instance. Agent OS remains independent."
  type        = bool
  default     = true
}

variable "elasticache_multi_az" {
  description = "Multi-AZ for legacy Redis OSS replication groups only. Valkey multi-AZ is set per role in valkey_instances."
  type        = bool
  default     = true
}

# eks
variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster. Supported: 1.34, 1.35."
  type        = string
  default     = "1.34"

  validation {
    condition     = contains(["1.34", "1.35"], var.k8s_version)
    error_message = "k8s_version must be 1.34 or 1.35; EKS add-on pins are defined for those versions only."
  }
}

variable "eks_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes nodes."
  type        = string
  default     = "m6a.xlarge"
}

variable "eks_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "t3a.xlarge,t3.xlarge,m5a.xlarge,m5.xlarge,m6a.xlarge,m6i.xlarge,m7a.xlarge,m7i.xlarge,r5a.xlarge,m4.xlarge"
}

variable "eks_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
  default     = 75
  validation {
    condition     = var.eks_spot_instance_percent >= 0 && var.eks_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "eks_min_node_count" {
  description = "The minimum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 4
}

variable "eks_max_node_count" {
  description = "The maximum number of nodes to run in the Kubernetes cluster."
  type        = number
  default     = 50
}

variable "eks_admin_arns" {
  description = "IAM user or role ARNs, including IAM Identity Center (SSO) role ARNs, granted EKS cluster-admin access."
  type        = list(string)
  default     = []
}

variable "create_autoscaling_linked_role" {
  description = "Create the account autoscaling IAM service-linked role. When disabling after it was created, run `tofu state rm 'module.cluster.aws_iam_service_linked_role.autoscaling[0]'` before apply so the role is left in AWS."
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Enable Karpenter autoscaling (SQS, IAM, Helm controller, EC2NodeClass, NodePools)."
  type        = bool
  default     = false
}

variable "enable_legacy_mng_pools" {
  description = "Keep legacy on-demand and spot EKS managed node groups during Karpenter migration."
  type        = bool
  default     = true

  validation {
    condition     = var.enable_karpenter || var.enable_legacy_mng_pools
    error_message = "At least one worker capacity source must be enabled: enable_karpenter or enable_legacy_mng_pools."
  }
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version (OCI public.ecr.aws/karpenter/karpenter)."
  type        = string
  default     = "1.13.0"
}

variable "karpenter_iam_names" {
  description = "Optional override for Karpenter IAM role names."
  type = object({
    controller_role_name = optional(string)
    node_role_name       = optional(string)
  })
  default = {}
}

variable "eks_system_managed_node_group" {
  description = "System EKS managed node group for Karpenter controller and cluster add-on DaemonSets. Default node group and EC2 Name: <workspace>-node-default (e.g. paragon-admin-a1b2c3d4-node-default)."
  type = object({
    map_key         = optional(string, "node-default")
    name            = optional(string)
    use_name_prefix = optional(bool, false)
    ec2_name_tag    = optional(string)
    instance_types  = optional(list(string))
    min_size        = optional(number, 2)
    max_size        = optional(number, 3)
    desired_size    = optional(number, 2)
    labels          = optional(map(string), { "karpenter.sh/controller" = "true" })
  })
  default = {}
}

variable "ami_release_version" {
  description = "Optional AMI release version pin applied to every managed node group. Only safe when all groups share one AMI family; for Bottlerocket system + AL2023 legacy coexistence, use ami_release_versions instead."
  type        = string
  default     = null
}

variable "ami_release_versions" {
  description = "Optional map of managed node group key (system, ondemand, spot) to AMI release version pin. When non-empty, overrides ami_release_version and pins only the listed groups."
  type        = map(string)
  default     = {}
}

variable "use_latest_ami_release_version" {
  description = "When true, resolve the latest AMI release version per node group ami_type for the cluster Kubernetes version at plan/apply."
  type        = bool
  default     = false
}

# security
variable "master_guardduty_account_id" {
  description = "Optional AWS account id to delegate GuardDuty control to."
  type        = string
  default     = null
}

variable "mfa_enabled" {
  description = "Whether to require MFA for certain configurations (e.g. cloudtrail s3 bucket deletion)"
  type        = bool
  default     = false
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist ssh access."
  type        = string
  default     = ""
}

variable "disable_cloudtrail" {
  description = "Used to specify that Cloudtrail is disabled."
  type        = bool
  default     = true
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
  default     = false
}

variable "app_bucket_expiration" {
  description = "The number of days to retain S3 app data before deleting"
  type        = number
  default     = 90
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
  default     = 365
}

variable "auditlogs_lock_enabled" {
  description = "Whether to enable S3 Object Lock for the audit logs bucket."
  type        = bool
  default     = false
}

variable "s3_kms_encryption_enabled" {
  description = "Encrypt the app, CDN, audit logs, and managed sync S3 buckets with AWS KMS (SSE-KMS) instead of S3-managed keys (SSE-S3). Existing deployments default to SSE-S3; enable for new installs or to migrate existing buckets to KMS. The logs bucket always uses SSE-S3 because ALB and S3 server access logs do not support SSE-KMS."
  type        = bool
  default     = false
}

variable "s3_kms_key_arn" {
  description = "ARN of an existing KMS key to use for S3 bucket encryption. When null and s3_kms_encryption_enabled is true, a dedicated KMS key is created and managed by Terraform. Ignored when s3_kms_encryption_enabled is false."
  type        = string
  default     = null
}

# network firewall
variable "network_firewall" {
  description = "Optional AWS Network Firewall for egress inspection with RAM-shared rule group ARNs (stateful or stateless). Enable on initial deployment only; not supported when adding to an existing workspace. Logs go to <workspace>-logs."
  type = object({
    enabled = optional(bool, false)

    rule_group_arns = optional(list(string), [])

    stateless_default_actions          = optional(list(string), ["aws:forward_to_sfe"])
    stateless_fragment_default_actions = optional(list(string), ["aws:forward_to_sfe"])

    # STRICT_ORDER (AWS-recommended) evaluates stateful rule groups by priority. It is
    # required when any referenced rule group was created with STRICT_ORDER. DEFAULT_ACTION_ORDER
    # lets the Suricata engine decide order and forbids priority/stateful_default_actions.
    stateful_rule_order      = optional(string, "STRICT_ORDER")
    stateful_default_actions = optional(list(string), ["aws:drop_strict", "aws:alert_strict"])
  })
  default = { enabled = false }

  validation {
    condition = (
      !var.network_firewall.enabled ||
      length(var.network_firewall.rule_group_arns) > 0
    )
    error_message = "When network_firewall.enabled is true, provide at least one rule_group_arn (RAM-shared)."
  }

  validation {
    condition     = contains(["STRICT_ORDER", "DEFAULT_ACTION_ORDER"], var.network_firewall.stateful_rule_order)
    error_message = "network_firewall.stateful_rule_order must be STRICT_ORDER or DEFAULT_ACTION_ORDER."
  }
}

# bastion
variable "bastion_enabled" {
  description = "Whether to create the bastion host and its associated Cloudflare tunnel."
  type        = bool
  default     = true
}

variable "bastion_tags" {
  description = "Optional additional tags applied to bastion resources (e.g. customer SCP-required tags)."
  type        = map(string)
  default     = {}
}

# cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS`"
  type        = string
  sensitive   = true
  default     = "dummy-cloudflare-tokens-must-be-40-chars"
}

variable "cloudflare_tunnel_enabled" {
  description = "Flag whether to enable Cloudflare Zero Trust tunnel for bastion"
  type        = bool
  default     = false
}

variable "cloudflare_tunnel_subdomain" {
  description = "Subdomain under the Cloudflare Zone to create the tunnel"
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_zone_id" {
  description = "Zone ID for Cloudflare domain"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_tunnel_account_id" {
  description = "Account ID for Cloudflare account"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_tunnel_email_domain" {
  description = "Email domain for Cloudflare access"
  type        = string
  sensitive   = true
  default     = "useparagon.com"
}

variable "migrated_workspace" {
  description = "Override the workspace name to preserve naming conventions when migrating from legacy workspaces"
  type        = string
  default     = null
}

variable "migrated_passwords" {
  description = "Override credentials to preserve complexity conventions when migrating from legacy workspaces"
  type        = map(string)
  default     = {}
}

variable "cdn_bucket_acl_reset" {
  description = "Reset the CDN S3 bucket ACL to private before BucketOwnerEnforced. Defaults to false; set true once when migrating a legacy CDN bucket with existing ACL grants, then remove."
  type        = bool
  default     = false
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
  default     = false
}

variable "valkey_enabled" {
  description = "Create the Paragon Valkey catalog (cache, queue, system, managed_sync) alongside legacy Redis. An existing Agent OS stack already sets this for its own Valkey; it does not add the Paragon catalog there."
  type        = bool
  default     = false
}

variable "paragon_valkey_on_agent_os" {
  description = "On an Agent OS stack, also create the Paragon Valkey catalog (cache, queue, system, managed sync). Leave false on existing Agent OS installs. Ignored when agent_os_enabled is false; valkey_enabled selects the catalog there. elasticache_multiple_instances still chooses one shared instance or one per instance."
  type        = bool
  default     = false
}

variable "agent_os_enabled" {
  description = "Whether to enable Agent OS. Requires managed_sync_enabled. Its Valkey is created from that flag and does not use valkey_enabled. Turning this off after apply is destructive."
  type        = bool
  default     = false

  validation {
    condition     = !var.agent_os_enabled || var.managed_sync_enabled
    error_message = "Agent OS requires Managed Sync. Set managed_sync_enabled = true when agent_os_enabled is true."
  }
}

variable "postgres_instances" {
  description = <<-EOT
    Per-instance PostgreSQL overrides keyed by logical name (cerberus, eventlogs, hermes, triggerkit, zeus, managed_sync, paragon, agent_os).
    Omitted keys and null optional fields retain built-in defaults derived from workspace-level rds_* settings and rds_multiple_instances / feature flags.
    Engine version and logging parameters are workspace-wide only (single shared DB parameter group); use rds_postgres_version for engine version.
    Port is fixed at 5432 (shared Postgres security group).
  EOT
  type = map(object({
    identifier                          = optional(string)
    database_name                       = optional(string)
    instance_class                      = optional(string)
    allocated_storage                   = optional(number)
    max_allocated_storage               = optional(number)
    multi_az                            = optional(bool)
    availability_zone                   = optional(string)
    read_replica                        = optional(bool)
    replica_instance_class              = optional(string)
    storage_type                        = optional(string)
    iops                                = optional(number)
    storage_throughput                  = optional(number)
    backup_retention_days               = optional(number)
    backup_window                       = optional(string)
    maintenance_window                  = optional(string)
    enabled_cloudwatch_logs_exports     = optional(list(string))
    monitoring_interval                 = optional(number)
    performance_insights_enabled        = optional(bool)
    performance_insights_retention_days = optional(number)
    ca_cert_identifier                  = optional(string)
    auto_minor_version_upgrade          = optional(bool)
    allow_major_version_upgrade         = optional(bool)
    apply_immediately                   = optional(bool)
    deletion_protection                 = optional(bool)
    kms_key_arn                         = optional(string)
    tags                                = optional(map(string))
  }))
  default  = null
  nullable = true

  validation {
    condition = var.postgres_instances == null || alltrue([
      for key, cfg in var.postgres_instances :
      contains(["cerberus", "eventlogs", "hermes", "triggerkit", "zeus", "managed_sync", "paragon", "agent_os"], key) &&
      (cfg.identifier == null || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", cfg.identifier))) &&
      (cfg.multi_az == null || cfg.availability_zone == null || !cfg.multi_az)
    ])
    error_message = "postgres_instances keys must be known logical names; identifiers must be valid RDS identifiers; availability_zone requires multi_az=false."
  }

  validation {
    condition = var.postgres_instances == null || alltrue([
      for _, cfg in var.postgres_instances :
      (cfg.iops == null) == (cfg.storage_throughput == null)
    ])
    error_message = "postgres_instances iops and storage_throughput must be set together."
  }
}

variable "redis_enabled" {
  description = "Keep legacy Redis 6 instances. Only set false after a verified Valkey cutover and soak."
  type        = bool
  default     = true

  validation {
    # Same condition as local.paragon_valkey_catalog. Variable validation cannot read locals.
    condition     = var.redis_enabled || (var.agent_os_enabled ? var.paragon_valkey_on_agent_os : var.valkey_enabled)
    error_message = "Keep Redis until the Paragon valkey_migration=true cutover and soak finish. The Paragon Valkey catalog must exist (valkey_enabled, or paragon_valkey_on_agent_os when Agent OS is on) before deleting Redis."
  }
}

variable "valkey_instances" {
  description = <<-EOT
    Overrides for Valkey instances (cache, queue, system, managed_sync, agent_os).
    Merged per key with the built-in catalog (cache.r6g.large cache/managed sync, t4g.medium queue, t4g.micro system). Empty uses defaults only.
    The catalog filter creates the instances: elasticache_multiple_instances selects one shared cache or separate instances; valkey_enabled creates the Paragon catalog except on an Agent OS stack, where paragon_valkey_on_agent_os is the opt-in; managed_sync_enabled and agent_os_enabled gate those instances.
    TLS defaults to false except agent_os (true); other instances may set tls_enabled when the app secret contract supports AUTH.
    kms_key_arn overrides at-rest encryption for that replication group only. CloudWatch logs stay on the workspace Valkey key.
    snapshot_name applies only at creation. Setting or changing it later replaces the replication group.
  EOT
  type = map(object({
    node_type               = optional(string)
    multi_az                = optional(bool)
    cluster_enabled         = optional(bool)
    engine_version          = optional(string)
    tls_enabled             = optional(bool)
    num_node_groups         = optional(number)
    replicas_per_node_group = optional(number)
    snapshot_retention_days = optional(number)
    log_retention_days      = optional(number)
    kms_key_arn             = optional(string)
    snapshot_name           = optional(string)
  }))
  default = {}

  validation {
    condition     = length(setsubtract(toset(keys(var.valkey_instances)), toset(["cache", "queue", "system", "managed_sync", "agent_os"]))) == 0
    error_message = "Valkey catalog supports only cache, queue, system, managed_sync and agent_os."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.valkey_instances :
      (cfg.node_type == null ? true : startswith(cfg.node_type, "cache.")) &&
      (cfg.engine_version == null ? true : can(regex("^[0-9]+\\.[0-9]+$", cfg.engine_version))) &&
      (cfg.snapshot_retention_days == null ? true : (cfg.snapshot_retention_days >= 0 && cfg.snapshot_retention_days <= 35)) &&
      (cfg.log_retention_days == null ? true : cfg.log_retention_days >= 1) &&
      (cfg.num_node_groups == null ? true : (cfg.num_node_groups >= 1 && cfg.num_node_groups <= 500)) &&
      (cfg.replicas_per_node_group == null ? true : (cfg.replicas_per_node_group >= 0 && cfg.replicas_per_node_group <= 5)) &&
      (cfg.kms_key_arn == null ? true : can(regex("^arn:aws[a-zA-Z-]*:kms:[a-z0-9-]+:[0-9]{12}:(key|alias)/.+$", cfg.kms_key_arn))) &&
      (cfg.snapshot_name == null ? true : trimspace(cfg.snapshot_name) != "")
    ])
    error_message = "Invalid Valkey instance settings (node type, engine, backups, topology, CMK ARN or snapshot)."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.valkey_instances :
      name == "agent_os" || cfg.tls_enabled != true
    ])
    error_message = "TLS is supported only on agent_os. cache, queue, system and managed_sync stay TLS-off until the Redis secret contract carries AUTH."
  }

  validation {
    condition = alltrue([
      for name, cfg in var.valkey_instances :
      cfg.cluster_enabled != false || cfg.num_node_groups == null
    ])
    error_message = "num_node_groups requires cluster_enabled=true."
  }
}

variable "agent_os_index_instance_types" {
  description = "Instance types for the Agent OS index managed node group / Karpenter NodePool."
  type        = list(string)
  default     = ["r6a.2xlarge", "r6i.2xlarge", "r5a.2xlarge"]
}

variable "agent_os_index_min_count" {
  description = "Minimum nodes in the Agent OS index managed node group."
  type        = number
  default     = 2
}

variable "agent_os_index_max_count" {
  description = "Maximum nodes in the Agent OS index managed node group / Karpenter nodes limit."
  type        = number
  default     = 4
}

variable "agent_os_index_cpu_limit" {
  description = "Maximum aggregate vCPU capacity for the Agent OS index Karpenter NodePool."
  type        = string
  default     = "32"
}

variable "agent_os_index_memory_limit" {
  description = "Maximum aggregate memory for the Agent OS index Karpenter NodePool."
  type        = string
  default     = "256Gi"
}

variable "agent_os_extract_instance_types" {
  description = "Extract node instance types. Default c6a.8xlarge for production; staging can override to c6a.4xlarge."
  type        = list(string)
  default     = ["c6a.8xlarge"]
}

variable "agent_os_extract_min_count" {
  description = "Minimum nodes in the Agent OS extraction managed node group."
  type        = number
  default     = 1
}

variable "agent_os_extract_max_count" {
  description = "Max extract nodes / Karpenter nodes limit. Staging 3, production 8 (covers 30 pods at 4/node)."
  type        = number
  default     = 8
}

variable "agent_os_extract_cpu_limit" {
  description = "Maximum aggregate vCPU capacity for the Agent OS extraction Karpenter NodePool."
  type        = string
  default     = "256"
}

variable "agent_os_extract_memory_limit" {
  description = "Maximum aggregate memory for the Agent OS extraction Karpenter NodePool."
  type        = string
  default     = "512Gi"
}

variable "msk_kafka_version" {
  description = "The Kafka version for the MSK cluster."
  type        = string
  default     = "3.9.x"
}

variable "msk_kafka_num_broker_nodes" {
  description = "The number of broker nodes for the MSK cluster."
  type        = number
  default     = 2
}

variable "msk_autoscaling_enabled" {
  description = "Whether to enable autoscaling for the MSK cluster."
  type        = bool
  default     = true
}

variable "msk_instance_type" {
  description = "The instance type for the MSK cluster."
  type        = string
  default     = "kafka.t3.small"
}

variable "env_overrides" {
  description = "Optional overrides for any infra-derived env key written to Secrets Manager (e.g. PARAGON_DOMAIN, ACCOUNT_PUBLIC_URL, CERBERUS_POSTGRES_PORT). Merged on top of computed defaults; app_secrets wins if the same key is set in both. Domain and *_PUBLIC_URL chart envKeys are owned by the paragon workspace `domain` variable — seed them here only for GitOps-only flows that read Secrets Manager without that workspace."
  type        = map(string)
  default     = null
}

variable "app_secrets" {
  description = "Customer-provided secret env vars (LICENSE, OAuth client secrets, SMTP, etc.) merged into the flat paragon/env Secrets Manager secret last. Overrides env_overrides when the same key is set in both."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "docker_registry_server" {
  description = "Docker registry server for application image pulls."
  type        = string
  default     = null
}

variable "docker_username" {
  description = "Docker username for application image pulls."
  type        = string
  default     = null
}

variable "docker_password" {
  description = "Docker password for application image pulls."
  type        = string
  sensitive   = true
  default     = null
}

variable "docker_email" {
  description = "Docker email for application image pulls."
  type        = string
  default     = null
}

variable "paragon_managed_sync_config" {
  description = "Optional managed-sync secret data to write to Secrets Manager. Null when managed sync is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "openobserve_email" {
  description = "Optional OpenObserve root user email. When set, used instead of the generated random email."
  type        = string
  default     = null
}

variable "secrets_recovery_window_in_days" {
  description = "Secrets Manager deletion recovery window for application secrets (env, docker-cfg, managed-sync, openobserve), MSK SCRAM credentials (AmazonMSK_*), and runtime handoff secrets. Set to 0 for immediate deletion so names are free after destroy; use 7–30 in production for undo protection."
  type        = number
  default     = 30

  validation {
    condition     = var.secrets_recovery_window_in_days == 0 || (var.secrets_recovery_window_in_days >= 7 && var.secrets_recovery_window_in_days <= 30)
    error_message = "secrets_recovery_window_in_days must be 0 (immediate) or between 7 and 30."
  }
}

locals {
  # hash of account ID to help ensure uniqueness of resources like S3 bucket names
  hash        = substr(sha256(data.aws_caller_identity.current.account_id), 0, 8)
  environment = "enterprise"

  # Tightest common AWS id suffix: ElastiCache replication_group "${workspace}-redis-cache" (max 40).
  workspace_max_length = 28
  workspace = coalesce(
    var.migrated_workspace,
    substr("paragon-${var.organization}-${local.hash}", 0, local.workspace_max_length)
  )

  # NOTE hash and workspace can't be included in tags since it creates a circular reference
  default_tags = merge(
    {
      Name        = "paragon-${var.organization}"
      Environment = local.environment
      Creator     = "Terraform"
      Workspace   = "enterprise-installer"
      aws-apn-id  = "pc:3elab41fw971izucbsjrfn81o"
    },
    trimspace(var.organization) == "" ? {} : { Organization = var.organization }
  )

  # get distinct values from comma-separated list, filter empty values and trim them
  # for `ip_whitelist`, if an ip doesn't contain a range at the end (e.g. `<IP_ADDRESS>/32`), then add `/32` to the end. `1.1.1.1` becomes `1.1.1.1/32`; `2.2.2.2/24` remains unchanged
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])

  # split instance types by comma, trim, and remove duplicates
  eks_ondemand_node_instance_type = distinct([for value in split(",", var.eks_ondemand_node_instance_type) : trimspace(value)])
  eks_spot_node_instance_type     = distinct([for value in split(",", var.eks_spot_node_instance_type) : trimspace(value)])

  # When using an assumed role the role itself must be referenced instead of the
  # current session identity arn, otherwise KMS key policies are rejected with
  # MalformedPolicyDocumentException.
  is_assumed_role = can(regex("assumed-role", data.aws_caller_identity.current.arn))
  assumed_role_parts = split(
    "/",
    replace(
      replace(
        data.aws_caller_identity.current.arn,
        ":sts:",
        ":iam:"
      ),
      ":assumed-role/",
      local.is_assumed_role && strcontains(data.aws_caller_identity.current.arn, ":assumed-role/AWSReservedSSO") ? ":role__TEMPORARY_DIVIDER__aws-reserved__TEMPORARY_DIVIDER__sso.amazonaws.com/" : ":role/"
    )
  )
  caller_arn = local.is_assumed_role ? replace(format("%s/%s", local.assumed_role_parts[0], local.assumed_role_parts[1]), "__TEMPORARY_DIVIDER__", "/") : data.aws_caller_identity.current.arn

  admin_arns = distinct(compact(concat(
    var.eks_admin_arns,
    [local.caller_arn]
  )))

  # Resolve Valkey in the root (like RDS). Sizing matches legacy Redis defaults but does not
  # read elasticache_node_type or elasticache_multi_az; topology still uses elasticache_multiple_instances.
  valkey_instance_defaults = {
    node_type               = "cache.r6g.large"
    multi_az                = false
    cluster_enabled         = false
    engine_version          = "7.2"
    tls_enabled             = false
    num_node_groups         = null
    replicas_per_node_group = null
    snapshot_retention_days = 5
    log_retention_days      = 30
    kms_key_arn             = null
    snapshot_name           = null
  }

  valkey_builtin_role_defaults = {
    cache        = { node_type = "cache.r6g.large" }
    queue        = { node_type = "cache.t4g.medium", cluster_enabled = false, multi_az = false }
    system       = { node_type = "cache.t4g.micro", cluster_enabled = false, multi_az = false }
    managed_sync = { node_type = "cache.r6g.large" }
    # Keep the Agent OS node type and Multi-AZ. Snapshots match the other Valkey roles.
    agent_os = {
      node_type               = "cache.t4g.medium"
      multi_az                = true
      cluster_enabled         = false
      snapshot_retention_days = 5
      tls_enabled             = true
    }
  }

  valkey_topology_role_defaults = {
    cache = {
      cluster_enabled = var.elasticache_multiple_instances
      multi_az        = var.elasticache_multiple_instances
    }
    managed_sync = {
      cluster_enabled = var.elasticache_multiple_instances
      multi_az        = var.elasticache_multiple_instances
    }
  }

  # Existing Agent OS stacks already set valkey_enabled for their own instance.
  # paragon_valkey_on_agent_os is what adds the Paragon catalog there.
  paragon_valkey_catalog = var.agent_os_enabled ? var.paragon_valkey_on_agent_os : var.valkey_enabled

  # One catalog. tfvars only overrides a key; the filter decides which instances exist.
  valkey_instances_config = {
    for name, _ in local.valkey_builtin_role_defaults :
    name => merge(
      local.valkey_instance_defaults,
      local.valkey_builtin_role_defaults[name],
      lookup(local.valkey_topology_role_defaults, name, {}),
      { for key, value in try(var.valkey_instances[name], {}) : key => value if value != null }
    )
  }

  valkey_instances = {
    for name, cfg in local.valkey_instances_config : name => cfg
    if(
      name == "agent_os" && var.agent_os_enabled && var.managed_sync_enabled
      ) || (
      name != "agent_os" &&
      local.paragon_valkey_catalog &&
      (var.elasticache_multiple_instances || name == "cache") &&
      (var.managed_sync_enabled || name != "managed_sync")
    )
  }

  # Shared mode has no queue, system, or managed_sync instance. Those Redis
  # keys still migrate into the cache Valkey.
  redis_migration_source = {
    cache        = contains(keys(local.valkey_instances), "cache")
    queue        = contains(keys(local.valkey_instances), "queue") || (!var.elasticache_multiple_instances && contains(keys(local.valkey_instances), "cache"))
    system       = contains(keys(local.valkey_instances), "system") || (!var.elasticache_multiple_instances && contains(keys(local.valkey_instances), "cache"))
    managed_sync = contains(keys(local.valkey_instances), "managed_sync") || (var.managed_sync_enabled && !var.elasticache_multiple_instances && contains(keys(local.valkey_instances), "cache"))
  }

  redis_kea_on_cluster = var.redis_enabled && var.elasticache_multiple_instances && (
    local.redis_migration_source.cache || local.redis_migration_source.managed_sync
  )
  redis_kea_on_standalone = var.redis_enabled && (
    (
      !var.elasticache_multiple_instances && (
        local.redis_migration_source.cache || local.redis_migration_source.queue || local.redis_migration_source.system || local.redis_migration_source.managed_sync
      )
      ) || (
      var.elasticache_multiple_instances && (local.redis_migration_source.queue || local.redis_migration_source.system)
    )
  )
  redis_kea_parameter_groups = toset(compact([
    local.redis_kea_on_cluster ? "cluster" : "",
    local.redis_kea_on_standalone ? "standalone" : "",
  ]))

  # Workflow always uses cache; shared mode maps queue, system and Managed Sync
  # to the same cache Valkey. Agent OS always remains independent.
  valkey_role_instances = {
    for role in ["cache", "queue", "system", "workflow", "managed_sync", "agent_os"] :
    role => (role == "workflow" || (!var.elasticache_multiple_instances && contains(["queue", "system", "managed_sync"], role)) ? "cache" : role)
  }

  # Redis 6 endpoints only (ElastiCache module keys). Workflow is a logical
  # chart role that shares cache; app_env and paragon resolve it from cache.
  redis_connections = var.redis_enabled ? module.redis.elasticache : {}

  valkey_enabled = length(local.valkey_instances) > 0
}
