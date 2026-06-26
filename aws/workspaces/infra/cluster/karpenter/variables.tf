variable "create" {
  description = "Whether to install the Karpenter Helm controller."
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

variable "chart_version" {
  description = "Karpenter Helm chart version."
  type        = string
}

variable "interruption_queue_name" {
  description = "SQS queue name for Helm settings.interruptionQueue."
  type        = string
}
