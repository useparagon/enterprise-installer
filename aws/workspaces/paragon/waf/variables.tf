variable "workspace" {
  description = "The workspace name used as a prefix for WAF resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region for WAF log delivery source ARN conditions."
  type        = string
}

variable "waf_logs_enabled" {
  description = "Enable WAF traffic logging to a dedicated S3 bucket (aws-waf-logs-*)."
  type        = bool
}

variable "waf_logs_retention_days" {
  description = "Number of days to retain WAF logs in S3 before lifecycle expiration."
  type        = number
}

variable "waf_ip_whitelist" {
  description = "Comma-separated CIDRs to bypass WAF rules (office IPs). Empty = no whitelist rule."
  type        = string
}

variable "waf_ip_blacklist" {
  description = "Comma-separated CIDRs to always block. Empty = no blacklist rule."
  type        = string
}

variable "waf_rate_limit_global" {
  description = "Max requests per IP across all endpoints in the evaluation window."
  type        = number
}

variable "waf_rate_limit_global_window_sec" {
  description = "Evaluation window for global rate limit (60, 120, 300, or 600)."
  type        = number
}

variable "waf_rate_limit_paths" {
  description = "Map of URI path prefix to max requests per IP per window."
  type        = map(number)
}

variable "waf_rate_limit_path_window_sec" {
  description = "Evaluation window for path rate limits (60, 120, 300, or 600)."
  type        = number
}

variable "waf_ip_reputation_enabled" {
  description = "Enable the AWSManagedRulesAmazonIpReputationList managed rule group."
  type        = bool
}

variable "waf_bot_control_enabled" {
  description = "Enable the AWSManagedRulesBotControlRuleSet managed rule group (COMMON level)."
  type        = bool
}
