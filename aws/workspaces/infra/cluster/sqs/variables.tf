variable "cluster_name" {
  description = "EKS cluster name (used in queue name and EventBridge tags)."
  type        = string
}

variable "queue_name" {
  description = "SQS queue name for Karpenter interruption events. If null, uses Karpenter-<cluster_name>."
  type        = string
  default     = null
}

variable "rule_name_prefix" {
  description = "Prefix for EventBridge rule names."
  type        = string
  default     = "Karpenter"
}

variable "message_retention_seconds" {
  description = "SQS message retention."
  type        = number
  default     = 300
}

variable "kms_master_key_id" {
  description = "KMS key ID (CMK) for queue encryption at rest (SSE-KMS only; required for this workspace)."
  type        = string
}

variable "tags" {
  description = "Tags for SQS and EventBridge resources."
  type        = map(string)
  default     = {}
}

variable "create" {
  description = "Whether to create SQS queue and EventBridge rules."
  type        = bool
  default     = true
}
