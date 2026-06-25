variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

# Optional service principal for the azurerm / azuread providers when this workspace is
# the Terraform root. Leave null (omit in tfvars) to use ARM_* / Azure CLI / OIDC.
# When this path is used as a child module, omit these so the parent workspace owns
# provider auth (same env-based chain).
variable "azure_tenant_id" {
  description = "Azure AD tenant ID for provider auth. Optional if using ARM_TENANT_ID / CLI."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure AD application (client) ID for provider auth. Optional if using ARM_CLIENT_ID / CLI."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure AD client secret for provider auth. Optional if using ARM_CLIENT_SECRET / CLI."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

# account
variable "location" {
  description = "Azure geographic region to deploy resources in."
  type        = string
}

variable "organization" {
  description = "Name of organization to include in resource names."
  type        = string
}

variable "environment" {
  description = "Type of environment being deployed to."
  type        = string
  default     = "enterprise"
  nullable    = false
}

variable "ssh_whitelist" {
  description = "An optional list of IP addresses to whitelist SSH access."
  type        = string
  default     = ""
  nullable    = false
}

variable "bastion_vm_size" {
  description = "VM size for the bastion scale set (e.g. Standard_B1s). Must be available in the target region."
  type        = string
  default     = "Standard_B1s"
  nullable    = false
}

variable "vpc_cidr" {
  description = "CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
  default     = 365
  nullable    = false
}

variable "auditlogs_lock_enabled" {
  description = "Whether to lock the audit logs container immutability policy."
  type        = bool
  default     = false
  nullable    = false
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

# postgres
variable "postgres_redundant" {
  description = "Enable zone-redundant HA. Recommended: true for production (requires GP/MO SKU, not Burstable)."
  type        = bool
  default     = false
  nullable    = false
}

variable "postgres_sku_name" {
  description = "PostgreSQL SKU name (e.g. `B_Standard_B2s` or `GP_Standard_D2ds_v5`)"
  type        = string
  default     = "GP_Standard_D2ds_v5"
  nullable    = false
}

variable "postgres_base_sku_name" {
  description = "PostgreSQL SKU for secondary instances. Use GP_Standard_D2ads_v5 for HA support. SKU availability may vary by Azure region."
  type        = string
  default     = "B_Standard_B2s"
  nullable    = false
}

variable "postgres_version" {
  description = "PostgreSQL version (14, 15 or 16)"
  type        = string
  default     = "14"
  nullable    = false
}

variable "postgres_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
  default     = true
  nullable    = false
}

# redis
variable "redis_capacity" {
  description = "Used to configure the capacity of the Redis cache."
  type        = number
  default     = 1
  nullable    = false
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_capacity)
    error_message = "The capacity for the redis instance. It must be between 0 - 6 (inclusive)."
  }
}

variable "redis_base_capacity" {
  description = "Default capacity of the Redis cache for instances that don't use the main redis_capacity."
  type        = number
  default     = 1
  nullable    = false
  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_base_capacity)
    error_message = "The capacity for the redis instance. It must be between 0 - 6 (inclusive)."
  }
}

variable "redis_sku_name" {
  description = "The SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`)."
  type        = string
  default     = "Premium"
  nullable    = false
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "The sku_name for the redis instance. It must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "redis_base_sku_name" {
  description = "Default SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`) for instances that don't use the main redis_sku_name."
  type        = string
  default     = "Standard"
  nullable    = false
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_base_sku_name)
    error_message = "The sku_name for the redis instance. It must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "redis_ssl_only" {
  description = "Flag whether only SSL connections are allowed."
  type        = bool
  default     = false
  nullable    = false
}

variable "redis_multiple_instances" {
  description = "Whether or not to create multiple Redis instances."
  type        = bool
  default     = true
  nullable    = false
}

variable "redis_enabled" {
  description = "Deploy Azure Cache for Redis (legacy module). When false, no legacy Redis resources are created."
  type        = bool
  default     = true
}

variable "redis_managed_enabled" {
  description = "Deploy Azure Managed Redis (Redis 7.4). When false, the redis-managed module is not created. May be true alongside redis_enabled during customer migration (both modules run in parallel)."
  type        = bool
  default     = false

  validation {
    condition     = var.redis_enabled || var.redis_managed_enabled
    error_message = "At least one of redis_enabled or redis_managed_enabled must be true."
  }
}

variable "redis_managed_instances" {
  description = <<-EOT
    Overrides for Azure Managed Redis instances (Redis 7.4). Each key is a logical name (cache, queue, system, managed-sync).
    Merged per key with redis_managed_instances_default (sku, ha_enabled, cluster_enabled, persistence_*). Null uses defaults only.
  EOT
  type = map(object({
    sku                   = optional(string)
    ha_enabled            = optional(bool)
    cluster_enabled       = optional(bool)
    persistence_mode      = optional(string)
    persistence_frequency = optional(string)
  }))
  default  = null
  nullable = true

  validation {
    condition = var.redis_managed_instances == null ? true : alltrue([
      for _, cfg in var.redis_managed_instances :
      cfg.persistence_mode == null || cfg.persistence_mode == "rdb" || cfg.persistence_mode == "aof"
    ])
    error_message = "persistence_mode must be \"rdb\" or \"aof\" when set."
  }

  validation {
    condition = var.redis_managed_instances == null ? true : alltrue([
      for _, cfg in var.redis_managed_instances :
      cfg.persistence_mode != "rdb" || cfg.persistence_frequency == null || (
        cfg.persistence_frequency == "1h" || cfg.persistence_frequency == "6h" || cfg.persistence_frequency == "12h"
      )
    ])
    error_message = "persistence_frequency must be 1h, 6h, or 12h when persistence_mode is rdb."
  }
}

variable "redis_managed_export_storage_enabled" {
  description = "Create blob storage and grant Managed Redis identities access for on-demand RDB export (CLI/portal)."
  type        = bool
  default     = false
}

variable "redis_managed_export_storage_replication_type" {
  description = "Replication type for the optional Managed Redis export storage account."
  type        = string
  default     = "LRS"
}

variable "redis_managed_clustering_policy" {
  description = "Clustering policy when cluster_enabled is true on an instance."
  type        = string
  default     = "OSSCluster"

  validation {
    condition     = contains(["OSSCluster", "EnterpriseCluster", "NoCluster"], var.redis_managed_clustering_policy)
    error_message = "redis_managed_clustering_policy must be OSSCluster, EnterpriseCluster, or NoCluster."
  }
}

variable "redis_managed_public_network_access" {
  description = "Public network access for Azure Managed Redis (Disabled recommended)."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.redis_managed_public_network_access)
    error_message = "redis_managed_public_network_access must be Enabled or Disabled."
  }
}

# aks
variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
  default     = "1.33"
  nullable    = false
}

variable "k8s_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
  default     = 3
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
  default     = 75
  nullable    = false
  validation {
    condition     = var.k8s_spot_instance_percent >= 0 && var.k8s_spot_instance_percent <= 100
    error_message = "Value must be between 0 - 100."
  }
}

variable "k8s_default_node_pool_vm_size" {
  description = "VM size for the AKS default (system) node pool. Must be available in the target region (e.g. Standard_B2s_v2 in japaneast)."
  type        = string
  default     = "Standard_B2s"
  nullable    = false
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
  default     = "Standard_B2ms"
  nullable    = false
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
  default     = "Standard_B2ms"
  nullable    = false
}

variable "k8s_sku_tier" {
  description = "The SKU Tier of the AKS cluster (`Free`, `Standard` or `Premium`)."
  type        = string
  default     = "Premium"
  nullable    = false
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.k8s_sku_tier)
    error_message = "The sku_tier for the AKS cluster. It must be `Free`, `Standard`, or `Premium`."
  }
}

variable "k8s_network_plugin" {
  description = "AKS network plugin. Use `azure` (recommended) or legacy `kubenet`."
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "kubenet"], var.k8s_network_plugin)
    error_message = "k8s_network_plugin must be `azure` or `kubenet`."
  }
}

variable "k8s_network_plugin_mode" {
  description = "Azure CNI mode. `overlay` assigns pod IPs from k8s_pod_cidr (default, IP-efficient). Set to null for legacy node-subnet mode (pod IPs from the VNet)."
  type        = string
  default     = "overlay"
  validation {
    condition     = var.k8s_network_plugin_mode == null || var.k8s_network_plugin_mode == "overlay"
    error_message = "k8s_network_plugin_mode must be null or `overlay`."
  }
}

variable "k8s_pod_cidr" {
  description = "Pod overlay CIDR (RFC 1918 private). Used when k8s_network_plugin_mode is `overlay` or k8s_network_plugin is `kubenet`. Must not overlap vpc_cidr or k8s_service_cidr."
  type        = string
  default     = "192.168.0.0/16"

  validation {
    condition     = (var.k8s_network_plugin != "kubenet" && var.k8s_network_plugin_mode != "overlay") || var.k8s_pod_cidr != null
    error_message = "k8s_pod_cidr is required when k8s_network_plugin_mode is overlay or k8s_network_plugin is kubenet."
  }
}

variable "k8s_service_cidr" {
  description = "Kubernetes service CIDR block (RFC 1918 private). Immutable after cluster creation."
  type        = string
  default     = "172.16.0.0/16"
}

variable "k8s_dns_service_ip" {
  description = "IP address within k8s_service_cidr for the cluster DNS service. Immutable after cluster creation."
  type        = string
  default     = "172.16.0.10"
}

variable "k8s_outbound_type" {
  description = "AKS outbound connectivity type. Use `userAssignedNATGateway` when the private subnet has a NAT Gateway (recommended)."
  type        = string
  default     = "userAssignedNATGateway"
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway", "userAssignedNATGateway"], var.k8s_outbound_type)
    error_message = "k8s_outbound_type must be one of: loadBalancer, userDefinedRouting, managedNATGateway, userAssignedNATGateway."
  }
}

variable "k8s_load_balancer_sku" {
  description = "SKU for the AKS load balancer."
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["basic", "standard"], var.k8s_load_balancer_sku)
    error_message = "k8s_load_balancer_sku must be `basic` or `standard`."
  }
}

variable "k8s_network_policy" {
  description = "Network policy engine. Leave null to disable, or set to `azure`, `calico`, or `cilium`."
  type        = string
  default     = null
  validation {
    condition     = var.k8s_network_policy == null ? true : contains(["azure", "calico", "cilium"], var.k8s_network_policy)
    error_message = "k8s_network_policy must be null, `azure`, `calico`, or `cilium`."
  }
}

variable "storage_account_tier" {
  description = "Storage account tier. Use \"Standard\" for new deployments that need public CDN container access (Premium BlockBlobStorage does not support it)."
  type        = string
  default     = "Premium"
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
  default     = false
  nullable    = false
}

variable "eventhub_namespace_sku" {
  description = "The SKU name for the Event Hubs namespace (Basic, Standard, Premium)."
  type        = string
  default     = "Standard"
  nullable    = false
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.eventhub_namespace_sku)
    error_message = "The sku_name must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "eventhub_capacity" {
  description = "The capacity units for the Event Hubs namespace (1-20 for Standard, 1-8 for Premium)."
  type        = number
  default     = 1
  nullable    = false
  validation {
    condition     = var.eventhub_capacity >= 1 && var.eventhub_capacity <= 20
    error_message = "The capacity must be between 1 and 20."
  }
}

variable "eventhub_auto_inflate_enabled" {
  description = "Whether to enable auto-inflate for the Event Hubs namespace."
  type        = bool
  default     = true
  nullable    = false
}

variable "eventhub_maximum_throughput_units" {
  description = "The maximum throughput units for auto-inflate (only applicable when auto_inflate_enabled is true)."
  type        = number
  default     = 20
  nullable    = false
}

locals {
  # hash of subscription ID to help ensure uniqueness of resources like bucket names
  hash      = substr(sha256(var.azure_subscription_id), 0, 8)
  workspace = nonsensitive("paragon-${var.organization}-${local.hash}")

  default_tags = {
    Name         = local.workspace
    Environment  = var.environment
    Organization = var.organization
    Creator      = "Terraform"
  }

  # get distinct values from comma-separated list, filter empty values and trim them
  # for `ip_whitelist`, if an ip doesn't contain a range at the end (e.g. `<IP_ADDRESS>/32`), then add `/32` to the end. `1.1.1.1` becomes `1.1.1.1/32`; `2.2.2.2/24` remains unchanged
  ssh_whitelist = distinct([for value in split(",", var.ssh_whitelist) : "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}" if trimspace(value) != ""])

  redis_managed_instance_defaults = {
    sku                   = "Balanced_B3"
    ha_enabled            = true
    cluster_enabled       = false
    persistence_mode      = null
    persistence_frequency = null
  }

  redis_managed_instances_default = {
    cache = {
      sku                   = "Balanced_B10"
      ha_enabled            = true
      cluster_enabled       = true
      persistence_mode      = null
      persistence_frequency = null
    }
    queue = {
      sku                   = "Balanced_B3"
      ha_enabled            = true
      cluster_enabled       = false
      persistence_mode      = null
      persistence_frequency = null
    }
    system = {
      sku                   = "Balanced_B3"
      ha_enabled            = true
      cluster_enabled       = false
      persistence_mode      = null
      persistence_frequency = null
    }
    managed-sync = {
      sku                   = "Balanced_B10"
      ha_enabled            = true
      cluster_enabled       = false
      persistence_mode      = null
      persistence_frequency = null
    }
  }

  redis_managed_instances_overrides = var.redis_managed_instances != null ? var.redis_managed_instances : {}

  redis_managed_instances_config = merge(
    local.redis_managed_instances_default,
    {
      for name, override in local.redis_managed_instances_overrides : name => merge(
        lookup(local.redis_managed_instances_default, name, local.redis_managed_instance_defaults),
        # Partial tfvars objects set omitted optional attributes to null; drop them so defaults survive merge.
        { for key, value in override : key => value if value != null },
      )
    },
  )

  redis_managed_instances = var.redis_multiple_instances ? (
    var.managed_sync_enabled ? local.redis_managed_instances_config : {
      for name, cfg in local.redis_managed_instances_config : name => cfg if name != "managed-sync"
    }
    ) : {
    cache = merge(local.redis_managed_instances_config["cache"], { cluster_enabled = false })
  }
}
# ArgoCD / GitOps variables for Azure infra workspace.
# paragon_domain is defined in variables.tf — not repeated here.

variable "argocd_enabled" {
  description = "Enable ArgoCD-based GitOps deployment. When true, bootstraps ArgoCD and ESO on the cluster, writes config to Key Vault, and applies ArgoCD Application manifests."
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
  description = "HTTPS Git repository URL for Argo CD App-of-Apps bootstrap. Leave empty to skip creating the root Application."
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
  description = "Optional managed-sync secret data to write to Key Vault. Null when managed sync is disabled."
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
  description = "Customer-facing Paragon domain (e.g. customer.example.com). Used for ingress, DNS zone, and written to Key Vault as PARAGON_DOMAIN and derived *_PUBLIC_URL values when argocd_enabled."
  type        = string
  default     = null
}

variable "argocd_env_overrides" {
  description = "Optional overrides for any infra-derived env key written to Key Vault. Merged on top of computed defaults; argocd_app_secrets wins if the same key is set in both."
  type        = map(string)
  default     = null
}

variable "argocd_app_secrets" {
  description = "Customer-provided secret env vars (LICENSE, OAuth client secrets, SMTP, etc.) merged into the flat env Key Vault secret last."
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
  description = "Ingress scheme for ArgoCD-managed ingress: internet-facing or internal."
  type        = string
  default     = "internet-facing"
  nullable    = false

  validation {
    condition     = contains(["internet-facing", "internal"], var.argocd_ingress_scheme)
    error_message = "argocd_ingress_scheme must be either 'internet-facing' or 'internal'."
  }
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  paragon_domain_trimmed = var.paragon_domain != null ? trimspace(var.paragon_domain) : ""

  argocd_domain = local.paragon_domain_trimmed

  # argocd_secrets_ready is used in validate_argocd_versions precondition only.
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
