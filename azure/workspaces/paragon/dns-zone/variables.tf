variable "enabled" {
  description = "Whether to create the Azure DNS zone."
  type        = bool
  default     = true
}

variable "workspace" {
  description = "Workspace prefix for resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that owns the DNS zone."
  type        = string
}

variable "domain" {
  description = "Root domain for the public zone (e.g. app.example.com)."
  type        = string
}

variable "dns_provider" {
  description = "Optional secondary DNS provider for NS delegation (cloudflare)."
  type        = string
  default     = "none"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for optional NS delegation."
  type        = string
  sensitive   = true
  default     = null
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id for optional NS delegation."
  type        = string
  default     = null
}

locals {
  has_cloudflare_credentials = var.dns_provider == "cloudflare" && var.cloudflare_api_token != null && var.cloudflare_zone_id != null
}
