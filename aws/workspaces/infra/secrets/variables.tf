variable "recovery_window_in_days" {
  description = "Days before Secrets Manager permanently deletes a secret after destroy. Use 0 for immediate deletion so the same secret name can be recreated (e.g. ephemeral stacks). Production values are typically 7–30."
  type        = number
}

variable "workspace" {
  description = "Workspace name used for Secrets Manager path prefix."
  type        = string
}

variable "organization" {
  description = "Organization name for the secret path."
  type        = string
}

variable "env_config" {
  description = "Flat map of chart env var key-value pairs for the paragon/env Secrets Manager secret."
  type        = map(string)
  sensitive   = true
}

variable "docker_config" {
  description = "Docker registry credentials as a JSON-encoded dockerconfigjson wrapper."
  type        = string
  sensitive   = true
  default     = null
}

variable "managed_sync_config" {
  description = "Optional managed-sync secret data. Null when managed sync is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "agent_os_enabled" {
  description = "Whether to create the Agent OS secrets."
  type        = bool
  default     = false
}

variable "agent_os_kms_key_arn" {
  description = "KMS key ARN used to encrypt the Agent OS secrets."
  type        = string
  default     = null
}

variable "agent_os_app_config" {
  description = "Agent OS app secret payload (datastores, broker, buckets). Null when Agent OS is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "agent_os_admin_config" {
  description = "Agent OS admin secret payload for the migration Job. Null when Agent OS is disabled."
  type        = map(string)
  sensitive   = true
  default     = null
}

variable "create_openobserve" {
  description = "When true, create the OpenObserve admin credentials secret."
  type        = bool
  default     = true
}

variable "openobserve_email" {
  description = "Optional OpenObserve root user email. When set, used instead of the generated random email."
  type        = string
  default     = null
}
