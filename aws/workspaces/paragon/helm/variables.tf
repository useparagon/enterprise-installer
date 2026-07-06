variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
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
  description = "Docker container registry server."
  type        = string
}

variable "docker_username" {
  description = "Docker username to pull images."
  type        = string
}

variable "docker_password" {
  description = "Docker password to pull images."
  type        = string
}

variable "docker_email" {
  description = "Docker email to pull images."
  type        = string
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

variable "certificate" {
  description = "The ARN of domain certificate."
  type        = string
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

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

variable "cluster_k8s_version" {
  description = "EKS control plane version from infra output. Used for Karpenter EC2NodeClass drift tagging."
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

variable "waf_web_acl_arn" {
  description = "Regional WAFv2 Web ACL ARN for the shared ALB. Empty disables WAF association."
  type        = string
  default     = ""
}

variable "enable_legacy_mng_pools" {
  description = "Whether legacy on-demand and spot managed node groups are active (from infra output)."
  type        = bool
  default     = true
}

variable "karpenter_enabled" {
  description = "Whether Karpenter autoscaling is enabled (from infra output)."
  type        = bool
  default     = false
}

variable "karpenter_aws" {
  description = "Karpenter AWS resources from infra output (IAM role, security groups, KMS). Null when Karpenter is disabled."
  type = object({
    node_role_name     = string
    security_group_ids = list(string)
    ebs_kms_key_arn    = string
  })
  default = null
}

variable "karpenter_node_os_volume_size_gib" {
  description = "Bottlerocket OS (control) volume size in GiB for Karpenter worker nodes (/dev/xvda)."
  type        = number
}

variable "karpenter_node_volume_size_gib" {
  description = "Bottlerocket container data volume size in GiB for Karpenter worker nodes (/dev/xvdb)."
  type        = number
}

variable "karpenter_node_pools" {
  description = "Karpenter NodePool definitions. Map key is the NodePool name."
  type = map(object({
    capacity_types = list(string)
    instance_types = list(string)
    cpu_limit      = string
    memory_limit   = string
    nodes_limit    = number
    weight         = number
    labels         = optional(map(string))
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })))
  }))
}

variable "karpenter_defaults" {
  description = "Optional overrides for Karpenter EC2NodeClass and shared NodePool defaults."
  type = object({
    ami_selector_alias              = optional(string)
    disruption_consolidation_policy = optional(string)
    disruption_consolidate_after    = optional(string)
    disruption_budgets = optional(list(object({
      nodes    = string
      reasons  = optional(list(string))
      schedule = optional(string)
      duration = optional(string)
    })))
    expire_after             = optional(string)
    termination_grace_period = optional(string)
    ec2_kubelet_max_pods     = optional(number)
  })
  default = {}
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
