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
