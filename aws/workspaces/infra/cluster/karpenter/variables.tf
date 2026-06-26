variable "create" {
  description = "Whether to install Karpenter Helm release and apply manifests."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS API endpoint for Helm settings."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS control plane version for EC2NodeClass drift tagging."
  type        = string
}

variable "chart_version" {
  description = "Karpenter Helm chart version."
  type        = string
}

variable "interruption_queue_name" {
  description = "SQS queue name for Helm settings.interruptionQueue."
  type        = string
}

variable "node_iam_role_name" {
  description = "IAM role name for EC2NodeClass.spec.role."
  type        = string
}

variable "node_security_group_ids" {
  description = "Security group IDs for Karpenter worker nodes. Must match eks_managed_node_group (cluster primary + cluster SG from the EKS module)."
  type        = list(string)
}

variable "discovery_tag_value" {
  description = "Value for karpenter.sh/discovery subnet selector tag."
  type        = string
}

variable "availability_zones" {
  description = "VPC availability zone names for NodePool topology requirements."
  type        = list(string)
}

variable "ec2_node_classes" {
  description = "EC2NodeClass definitions keyed by class name (one per worker capacity type)."
  type = map(object({
    ec2_name_tag = string
  }))
}

variable "ebs_kms_key_arn" {
  description = "KMS key ARN for encrypted root volumes on Karpenter nodes."
  type        = string
}

variable "ebs_volume_size_gib" {
  description = "Root volume size in GiB for Karpenter nodes."
  type        = number
}

variable "ami_selector_alias" {
  description = "Bottlerocket AMI selector alias for EC2NodeClass."
  type        = string
  default     = "bottlerocket@latest"
}

variable "ec2_kubelet_max_pods" {
  description = "Optional kubelet maxPods for EC2NodeClass."
  type        = number
  default     = null
}

variable "node_pool_definitions" {
  description = "NodePool definitions (capacity, weight, labels)."
  type = map(object({
    capacity_types      = list(string)
    weight              = optional(number)
    capacity_type_label = string
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })))
    labels = optional(map(string))
  }))
}

variable "node_pool_effective" {
  description = "Merged per-NodePool settings (limits, requirements, disruption)."
  type = map(object({
    cpu_limit                       = string
    memory_limit                    = string
    nodes_limit                     = number
    instance_types                  = list(string)
    instance_categories             = list(string)
    architectures                   = list(string)
    instance_hypervisor_values      = list(string)
    disruption_consolidation_policy = string
    disruption_consolidate_after    = string
    disruption_budgets = list(object({
      nodes    = string
      reasons  = optional(list(string))
      schedule = optional(string)
      duration = optional(string)
    }))
    expire_after             = string
    termination_grace_period = string
    weight                   = optional(number)
    capacity_types           = list(string)
    capacity_type_label      = string
    ec2_node_class_name      = string
    ec2_name_tag             = string
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })))
    labels = optional(map(string))
  }))
}
