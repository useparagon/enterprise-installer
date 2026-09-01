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
  description = "Array of ARNs for IAM users, groups or roles that should have admin access to cluster. Includes the Terraform caller."
  type        = list(string)
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster. Supported: 1.34, 1.35."
  type        = string

  validation {
    condition     = contains(["1.34", "1.35"], var.k8s_version)
    error_message = "k8s_version must be 1.34 or 1.35; EKS add-on pins are defined for those versions only."
  }
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

variable "bastion_enabled" {
  description = "Whether the bastion host is enabled."
  type        = bool
}

variable "bastion_role_arn" {
  description = "ARN of IAM role associated with Bastion."
  type        = string
  default     = null
}

variable "bastion_security_group_id" {
  description = "Security Group ID associated with Bastion."
  type        = string
  default     = null
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

variable "egress_ready" {
  description = "Set when private egress routing is ready. Implicit apply-order dependency for internet-bootstrapping workloads."
  type        = string
}

data "aws_caller_identity" "current" {}
