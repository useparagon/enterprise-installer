variable "workspace" {
  description = "EKS cluster / workspace name (karpenter.sh/discovery tag value)."
  type        = string
}

variable "k8s_version" {
  description = "EKS control plane version for EC2NodeClass drift tagging."
  type        = string
}

variable "ebs_os_volume_size_gib" {
  description = "Bottlerocket OS (control) volume size in GiB for Karpenter worker nodes (/dev/xvda)."
  type        = number
}

variable "ebs_volume_size_gib" {
  description = "Bottlerocket container data volume size in GiB for Karpenter worker nodes (/dev/xvdb)."
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

  validation {
    condition     = length(var.karpenter_node_pools) > 0
    error_message = "At least one Karpenter NodePool must be defined in karpenter_node_pools."
  }
}

variable "karpenter_defaults" {
  description = "Optional overrides for shared EC2NodeClass and NodePool defaults (disruption, AMI, etc.)."
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
