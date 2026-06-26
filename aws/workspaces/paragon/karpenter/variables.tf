variable "workspace" {
  description = "EKS cluster / workspace name (karpenter.sh/discovery tag value)."
  type        = string
}

variable "k8s_version" {
  description = "EKS control plane version for EC2NodeClass drift tagging."
  type        = string
}

variable "ebs_volume_size_gib" {
  description = "Root volume size in GiB for Karpenter worker nodes."
  type        = number
}

variable "aws" {
  description = "Karpenter AWS resources created by the infra workspace."
  type = object({
    node_role_name     = string
    security_group_ids = list(string)
    ebs_kms_key_arn    = string
  })
}

variable "eks_ondemand_node_instance_type" {
  description = "Instance types for the default on-demand Karpenter NodePool."
  type        = list(string)
}

variable "eks_spot_node_instance_type" {
  description = "Instance types for the default spot Karpenter NodePool."
  type        = list(string)
}

variable "eks_spot_instance_percent" {
  description = "Spot share of worker capacity (drives default-spot vs default-ondemand weights and limits)."
  type        = number
}

variable "eks_max_node_count" {
  description = "Maximum worker nodes used to derive Karpenter NodePool limits."
  type        = number
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
    expire_after         = optional(string)
    termination_grace_period = optional(string)
    ec2_kubelet_max_pods = optional(number)
  })
  default = {}
}

variable "karpenter_node_pool_overrides" {
  description = "Optional per-NodePool overrides (limits, disruption, instance types)."
  type = map(object({
    instance_types                  = optional(list(string))
    instance_categories             = optional(list(string))
    ec2_name_tag                    = optional(string)
    cpu_limit                       = optional(string)
    memory_limit                    = optional(string)
    nodes_limit                     = optional(number)
    expire_after                    = optional(string)
    termination_grace_period        = optional(string)
    disruption_consolidation_policy = optional(string)
    disruption_consolidate_after    = optional(string)
    disruption_budgets = optional(list(object({
      nodes    = string
      reasons  = optional(list(string))
      schedule = optional(string)
      duration = optional(string)
    })))
  }))
  default = {}
}

variable "karpenter_node_pools" {
  description = "Additional custom NodePool definitions beyond default-spot and default-ondemand."
  type = map(object({
    capacity_types      = list(string)
    weight              = optional(number)
    capacity_type_label = optional(string)
    instance_types      = optional(list(string))
    cpu_limit           = optional(string)
    memory_limit        = optional(string)
    nodes_limit         = optional(number)
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })))
    labels = optional(map(string))
  }))
  default = {}
}
