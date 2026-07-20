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

variable "create_openobserve" {
  description = "When true, create the OpenObserve admin credentials secret."
  type        = bool
  default     = true
}
