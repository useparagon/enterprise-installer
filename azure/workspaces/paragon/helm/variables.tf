variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "workspace" {
  description = "The name of the resource group that all resources are associated with."
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "docker_registry_server" {
  description = "Container registry server for image pull credentials (e.g. docker.io or artifactory.example.com). Must match the host portion of global.imageRegistry when using a private registry."
  type        = string
}

variable "docker_cfg_secret_name" {
  description = "Key Vault secret name for docker credentials. Null when unused (e.g. pre-provisioned Artifactory pull secret)."
  type        = string
  default     = null
}

variable "docker_pull_secret_name" {
  description = "Kubernetes secret name for registry pull credentials."
  type        = string
  default     = "docker-cfg"
}

variable "create_docker_pull_secret" {
  description = "Create the registry pull secret in the paragon namespace. Set false when the customer pre-provisions the secret and sets global.imagePullSecrets in helm_values."
  type        = bool
  default     = true
}

variable "docker_username" {
  description = "Docker username to pull images."
  type        = string
  default     = null
}

variable "docker_password" {
  description = "Docker password to pull images."
  type        = string
  default     = null
  sensitive   = true
}

variable "docker_email" {
  description = "Docker email to pull images."
  type        = string
  default     = null
}

variable "env_secret_name" {
  description = "Key Vault secret name for shared Paragon application secrets."
  type        = string
}

variable "external_secrets_client_id" {
  description = "Client ID of the user-assigned identity used by External Secrets Operator."
  type        = string
}

variable "external_secrets_tenant_id" {
  description = "Azure tenant ID used for External Secrets workload identity."
  type        = string
}

variable "external_secrets_workload_identity_ready" {
  description = "Opaque revision proving the federated credential and Key Vault policy exist before the operator is installed."
  type        = string
}

variable "legacy_external_secrets_client_id" {
  description = "Legacy Azure client ID retained only during the pre-migration workload-identity cutover."
  type        = string
  default     = null
  sensitive   = true
}

variable "legacy_external_secrets_client_secret" {
  description = "Legacy Azure client secret retained only during the pre-migration workload-identity cutover."
  type        = string
  default     = null
  sensitive   = true
}

variable "openobserve_email" {
  description = "OpenObserve admin login email."
  type        = string
  default     = null
}

variable "openobserve_password" {
  description = "OpenObserve admin login password."
  type        = string
  default     = null
}

variable "logs_bucket" {
  description = "Bucket to store system logs."
  type        = string
}

variable "helm_values" {
  description = "Object containing values to pass to the helm chart."
  type        = any
  sensitive   = true
}

variable "secrets_revision" {
  description = "Opaque revision of cloud-store secrets synced via ESO. Included in secret_hash so secret-only changes still force Helm upgrades (Reloader remains the runtime path)."
  type        = string
  default     = ""
}

variable "feature_flags_content" {
  description = "Optional YAML content for feature flags when not using a git repository."
  type        = string
  default     = null
}

variable "flipt_options" {
  description = "Map of flipt configuration variables"
  type        = map(any)
  sensitive   = true
}

variable "microservices" {
  description = "The microservices running within the system."
  type = map(object({
    port             = number
    healthcheck_path = string
    public_url       = string
  }))
}

variable "public_microservices" {
  description = "The microservices running within the system exposed to the load balancer"
  type = map(object({
    port             = number
    healthcheck_path = string
    public_url       = string
  }))
}

variable "monitors_enabled" {
  description = "Specifies that monitors are enabled."
  type        = bool
}

variable "monitor_version" {
  description = "The version of the monitors to install."
  type        = string
}

variable "monitors" {
  description = "The monitors running within the system."
  type = map(object({
    port       = number
    public_url = string
  }))
}

variable "public_monitors" {
  description = "The monitors running within the system exposed to the load balancer"
  type = map(object({
    port       = number
    public_url = string
  }))
}

variable "ingress_scheme" {
  description = "Whether the load balancer is 'internet-facing' (public) or 'internal' (private)"
  type        = string
}

variable "nginx_public" {
  description = "Whether the nginx controller should expose a public LoadBalancer."
  type        = bool
  default     = true
}

variable "agc_active" {
  description = "Whether Application Gateway for Containers is active (forwarded-headers on nginx when the AGC subnet CIDR is known)."
  type        = bool
  default     = false
}

variable "agc_direct" {
  description = "Whether AGC routes directly to Services (nginx Ingress objects are disabled)."
  type        = bool
  default     = false
}

variable "agc_gateway_name" {
  description = "Gateway name used for cert-manager HTTP-01 challenges when agc_direct is true."
  type        = string
  default     = "paragon-agc"
}

variable "agc_subnet_cidr" {
  description = "CIDR of the AGC association subnet (used as nginx proxy-real-ip-cidr during transition)."
  type        = string
  default     = null
}

variable "azure_subscription_id" {
  description = "Azure subscription ID for cert-manager azureDNS solver."
  type        = string
  sensitive   = true
  default     = null
}

variable "domain" {
  description = "Root domain for wildcard certificate."
  type        = string
  default     = null
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
}

variable "managed_sync_version" {
  description = "The version of the Managed Sync helm chart to install."
  type        = string
}

variable "agent_os_enabled" {
  description = "Whether to enable Agent OS. Requires managed_sync_enabled."
  type        = bool

  validation {
    condition     = !var.agent_os_enabled || var.managed_sync_enabled
    error_message = "Agent OS requires Managed Sync. Set managed_sync_enabled = true when agent_os_enabled is true."
  }
}

variable "agent_os_version" {
  description = "The version of the Agent OS helm chart to install."
  type        = string
}

# Agent OS cloud secret names and workload identity are supplied by the parent workspace.
variable "agent_os_secret_names" {
  description = "Key Vault secret names used to assemble Agent OS Kubernetes secrets."
  type = object({
    app    = string
    admin  = string
    vendor = string
  })
  default = null
}

variable "agent_os_workload_identity_client_id" {
  description = "Client ID of the Agent OS user-assigned workload identity."
  type        = string
  default     = null
}

variable "agent_os_workload_identity_ready" {
  description = "Opaque revision proving the Agent OS federation and blob role assignment exist."
  type        = string
  default     = null
}

variable "key_vault_name" {
  description = "Key Vault name that stores Paragon runtime secrets."
  type        = string
}

variable "managed_sync_secret_name" {
  description = "Key Vault secret name for managed-sync secrets."
  type        = string
  default     = null
}

variable "openobserve_secret_name" {
  description = "Key Vault secret name for OpenObserve credentials."
  type        = string
  default     = null
}

locals {
  chart_names     = var.monitors_enabled ? ["paragon-logging", "paragon-monitoring", "paragon-onprem"] : ["paragon-logging", "paragon-onprem"]
  chart_directory = "../charts"
  chart_hashes = {
    for chart_name in local.chart_names :
    chart_name => base64sha512(
      jsonencode(
        {
          for path in sort(fileset("${local.chart_directory}/${chart_name}", "**")) :
          path => filebase64sha512("${local.chart_directory}/${chart_name}/${path}")
        }
      )
    )
  }
}
