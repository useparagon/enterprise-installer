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
  description = "Comma-separated CIDRs to bypass WAF rules (office IPs). Empty = no whitelist rule."
  type        = string
}

variable "waf_ip_blacklist" {
  description = "Comma-separated CIDRs to always block. Empty = no blacklist rule."
  type        = string
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
  description = <<-EOT
    Map of AWS WAF managed rule groups to attach to the Web ACL. Empty = no managed rules.

    Each key is the Web ACL rule name (unique, used for metrics). Each value configures one
    managed rule group from an AWS or marketplace vendor.

    Fields:
    - name (required): managed rule group name, e.g. AWSManagedRulesCommonRuleSet
    - vendor_name: vendor (default AWS). See ListAvailableManagedRuleGroups in AWS WAF API.
    - priority: rule evaluation order (lower runs first). Auto-assigned after IP/rate rules when null.
    - override_action: "none" (enforce group defaults) or "count" (count all matches, block none)
    - excluded_rules: rule names inside the group set to Count (legacy; prefer rule_action_overrides)
    - rule_action_overrides: per-rule actions inside the group — "count", "block", or "allow"
    - bot_control_inspection_level: "COMMON" or "TARGETED" — only for AWSManagedRulesBotControlRuleSet

    Reference config (Paragon SaaS): paragon/terraform/workspaces/environment/shared/waf.tf
  EOT
  type = map(object({
    name                       = string
    vendor_name                = optional(string, "AWS")
    priority                   = optional(number)
    override_action            = optional(string, "none")
    excluded_rules             = optional(list(string), [])
    rule_action_overrides      = optional(map(string), {})
    bot_control_inspection_level = optional(string)
  }))
}
