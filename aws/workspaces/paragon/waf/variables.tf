variable "workspace" {
  description = "The workspace name used as a prefix for WAF resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region for WAF log delivery source ARN conditions."
  type        = string
}

variable "waf_logs_retention_days" {
  description = "Number of days to retain WAF logs in S3 before lifecycle expiration."
  type        = number
}

variable "waf_ip_whitelist" {
  description = "CIDRs to bypass WAF rules (office IPs). Empty list = no whitelist rule."
  type        = list(string)
}

variable "waf_ip_blacklist" {
  description = "CIDRs to always block. Empty list = no blacklist rule."
  type        = list(string)
}

variable "waf_rate_limit_global" {
  description = "Max requests per IP across all endpoints in the evaluation window. null = no global rate limit rule."
  type        = number
  nullable    = true
}

variable "waf_rate_limit_global_window_sec" {
  description = "Evaluation window for global rate limit (60, 120, 300, or 600)."
  type        = number
}

variable "waf_rate_limit_paths" {
  description = "Map of URI path prefix to max requests per IP per window. Empty = no path rate limit rules."
  type        = map(number)
}

variable "waf_rate_limit_path_window_sec" {
  description = "Evaluation window for path rate limits (60, 120, 300, or 600)."
  type        = number
}

variable "waf_managed_rule_groups" {
  description = "Map of AWS WAF managed rule groups. See root variables.tf for field documentation."
  type = map(object({
    name                         = string
    vendor_name                  = optional(string)
    priority                     = optional(number)
    override_action              = optional(string)
    excluded_rules               = optional(list(string))
    rule_action_overrides        = optional(map(string))
    bot_control_inspection_level = optional(string)
  }))
}
