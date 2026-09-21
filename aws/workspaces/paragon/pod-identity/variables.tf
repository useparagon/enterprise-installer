variable "cluster_name" {
  description = "EKS cluster name for Pod Identity associations."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Paragon workloads."
  type        = string
}

variable "s3_role_arn" {
  description = "IAM role ARN for S3 access via EKS Pod Identity."
  type        = string
}

variable "service_accounts" {
  description = "Kubernetes ServiceAccount names that should assume the S3 Pod Identity role."
  type        = set(string)
}

variable "agent_os_enabled" {
  description = "Whether to create the Agent OS Pod Identity association."
  type        = bool
  default     = false
}

variable "agent_os_service_account" {
  description = "Kubernetes ServiceAccount used by Agent OS."
  type        = string
  default     = "agent-os"
}

variable "agent_os_role_arn" {
  description = "Dedicated IAM role ARN for Agent OS S3 access."
  type        = string
  default     = null
}
