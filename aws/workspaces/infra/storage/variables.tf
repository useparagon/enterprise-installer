variable "workspace" {
  description = "The name of the workspace resources are being created in."
}

variable "force_destroy" {
  description = "Whether to enable force destroy."
  type        = bool
}

variable "app_bucket_expiration" {
  description = "The number of days to retain S3 app data before deleting"
}

variable "auditlogs_retention_days" {
  description = "The number of days to retain audit logs before deletion."
  type        = number
}

variable "auditlogs_lock_enabled" {
  description = "Whether to enable S3 Object Lock for the audit logs bucket."
  type        = bool
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
}

variable "s3_kms_encryption_enabled" {
  description = "Encrypt the app, CDN, audit logs, and managed sync buckets with AWS KMS (SSE-KMS) instead of SSE-S3. The logs bucket always stays on SSE-S3 since ALB and S3 server access logs do not support SSE-KMS."
  type        = bool
  default     = false
}

variable "s3_kms_key_arn" {
  description = "ARN of an existing KMS key for S3 encryption. When null and s3_kms_encryption_enabled is true, a dedicated KMS key is created."
  type        = string
  default     = null
}

variable "admin_arns" {
  description = "IAM user/role ARNs with KMS administrative access, including the Terraform caller."
  type        = list(string)
}

variable "migrated" {
  description = "Whether the workspace is being migrated from a legacy workspace."
  type        = bool
  default     = false
}

variable "cdn_bucket_acl_reset" {
  description = "Reset the CDN S3 bucket ACL to private before BucketOwnerEnforced."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "network_firewall_enabled" {
  description = "Whether AWS Network Firewall is enabled (grants log delivery to the central logs bucket)."
  type        = bool
}
