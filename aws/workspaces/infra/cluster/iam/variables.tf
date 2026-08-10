variable "create" {
  description = "Whether to create Karpenter IAM roles and EKS associations."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region for ARNs and regional IAM conditions."
  type        = string
}

variable "tags" {
  description = "Tags for IAM roles and policies."
  type        = map(string)
  default     = {}
}

variable "controller_role_name" {
  description = "IAM role name for the Karpenter controller (EKS Pod Identity)."
  type        = string
}

variable "node_role_name" {
  description = "IAM role name for EC2 nodes launched by Karpenter."
  type        = string
}

variable "interruption_queue_arn" {
  description = "SQS queue ARN for Karpenter interruption handling."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS volumes and encrypted SQS messages."
  type        = string
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace for the Karpenter controller service account."
  type        = string
  default     = "kube-system"
}

variable "karpenter_service_account" {
  description = "Kubernetes service account name for Karpenter."
  type        = string
  default     = "karpenter"
}

variable "node_iam_role_additional_policies" {
  description = "Additional managed policy ARNs to attach to the Karpenter node role."
  type        = map(string)
  default     = {}
}

variable "ami_id_ssm_parameter_arns" {
  description = "Optional SSM parameter ARNs for AMI discovery."
  type        = list(string)
  default     = []
}

variable "cluster_ip_family" {
  description = "Cluster IP family (ipv4 or ipv6) for CNI policy selection."
  type        = string
  default     = "ipv4"
}

variable "attach_cni_policy_to_node" {
  description = "Whether to attach AmazonEKS_CNI_Policy to the Karpenter node role."
  type        = bool
  default     = true
}
