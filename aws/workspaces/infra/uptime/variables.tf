variable "uptime_api_token" {
  description = "BetterStack Uptime API token."
  type        = string
  sensitive   = true
  default     = null
}

variable "uptime_company" {
  description = "Company name shown in BetterStack Uptime monitors."
  type        = string
}

variable "uptime_policy" {
  description = "Escalation policy name associated with BetterStack Uptime monitors."
  type        = string
  default     = "Standard Escalation Policy"
}

variable "uptime_regions" {
  description = "Regions enabled for BetterStack Uptime monitors."
  type        = list(string)
  default     = ["as", "au", "eu", "us"]
}

variable "microservices" {
  description = "Public microservices to monitor."
  type        = map(any)
}

locals {
  # Token presence is sensitive; nonsensitive() is safe for a boolean gate.
  enabled = nonsensitive(var.uptime_api_token != null && var.uptime_api_token != "")
}
