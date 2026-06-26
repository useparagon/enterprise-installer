variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "aws_region" {
  description = "AWS region for regional resources (Karpenter IAM, SQS)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of VPC to create resources in."
  type        = string
}

variable "private_subnet_ids" {
  description = "The private subnet IDs within the VPC."
  type        = list(string)
}

variable "eks_admin_arns" {
  description = "Array of ARNs for IAM users, groups or roles that should have admin access to cluster. Used for viewing cluster resources in AWS dashboard."
  type        = list(string)
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

variable "eks_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on-demand nodes."
  type        = list(string)
}

variable "eks_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = list(string)
}

variable "eks_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
}

variable "eks_min_node_count" {
  description = "The minimum number of nodes to run in the Kubernetes cluster."
  type        = number
}

variable "eks_max_node_count" {
  description = "The maximum number of nodes to run in the Kubernetes cluster."
  type        = number
}

variable "kms_admin_role" {
  description = "ARN of IAM role allowed to administer KMS keys."
  type        = string
  default     = null
}

variable "bastion_role_arn" {
  description = "ARN of IAM role associated with Bastion."
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security Group ID associated with Bastion."
  type        = string
}

variable "create_autoscaling_linked_role" {
  description = "Whether or not to create an IAM role for autoscaling."
  type        = bool
}

variable "enable_karpenter" {
  description = "Enable Karpenter autoscaling (SQS, IAM, Helm controller, EC2NodeClass, NodePools)."
  type        = bool
}

variable "enable_legacy_mng_pools" {
  description = "Keep legacy on-demand and spot EKS managed node groups (migration mode). Requires enable_karpenter or this flag for worker capacity."
  type        = bool

  validation {
    condition     = var.enable_karpenter || var.enable_legacy_mng_pools
    error_message = "At least one worker capacity source must be enabled: enable_karpenter or enable_legacy_mng_pools."
  }
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version (OCI public.ecr.aws/karpenter/karpenter)."
  type        = string
}

variable "karpenter_iam_names" {
  description = "Optional override for Karpenter IAM role names."
  type = object({
    controller_role_name = optional(string)
    node_role_name       = optional(string)
  })
}

variable "karpenter_defaults" {
  description = "Optional overrides for Karpenter EC2NodeClass and shared NodePool defaults. Unset fields are derived from eks_* variables."
  type = object({
    ec2_node_class_name             = optional(string)
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
    ec2_name_tag             = optional(string)
    ec2_kubelet_max_pods     = optional(number)
  })
}

variable "karpenter_node_pool_overrides" {
  description = "Optional per-NodePool overrides (limits, disruption, instance types). Empty by default."
  type = map(object({
    instance_types                  = optional(list(string))
    instance_categories             = optional(list(string))
    ec2_node_class_name             = optional(string)
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
  })
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
}

variable "eks_system_managed_node_group" {
  description = "System EKS managed node group for Karpenter controller and cluster add-on DaemonSets. Default node group and EC2 Name: <workspace>-node-default (e.g. paragon-admin-a1b2c3d4-node-default)."
  type = object({
    map_key         = optional(string, "node-default")
    name            = optional(string)
    use_name_prefix = optional(bool, false)
    ec2_name_tag    = optional(string)
    instance_types  = optional(list(string), ["m6a.large"])
    min_size        = optional(number, 2)
    max_size        = optional(number, 3)
    desired_size    = optional(number, 2)
    labels          = optional(map(string), { "karpenter.sh/controller" = "true" })
  })
}

data "aws_caller_identity" "current" {}
