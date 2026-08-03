# Defaults and validation live in the root `gcp/workspaces/paragon/variables.tf`; this
# module only declares the shapes it consumes.

variable "workspace" {
  description = "The workspace name used as a prefix for Cloud Armor resources."
  type        = string
}

variable "waf_ip_whitelist" {
  description = "CIDRs that bypass every other Cloud Armor rule."
  type        = list(string)
}

variable "waf_ip_blacklist" {
  description = "CIDRs that are always denied."
  type        = list(string)
}

variable "waf_ip_blacklist_deny_status" {
  description = "HTTP status returned by the denylist rule."
  type        = number
}

variable "waf_rate_limit_global" {
  description = "Requests per key allowed across all paths in the evaluation window. null disables the rule."
  type        = number
  nullable    = true
}

variable "waf_rate_limit_global_window_sec" {
  description = "Evaluation window for the global rate limit."
  type        = number
}

variable "waf_rate_limit_paths" {
  description = "Map of URL path prefix to requests per key per window."
  type        = map(number)
}

variable "waf_rate_limit_path_window_sec" {
  description = "Evaluation window for the path rate limits."
  type        = number
}

variable "waf_rate_limit_options" {
  description = "Shared behaviour for the generated rate limit rules."
  type = object({
    action                     = optional(string)
    exceed_status              = optional(number)
    enforce_on_key             = optional(string)
    enforce_on_key_name        = optional(string)
    ban_duration_sec           = optional(number)
    ban_threshold_count        = optional(number)
    ban_threshold_interval_sec = optional(number)
    preview                    = optional(bool)
  })
}

variable "waf_preconfigured_rules" {
  description = "Google-managed (preconfigured) WAF rule sets to evaluate."
  type = map(object({
    rule_set         = string
    sensitivity      = optional(number)
    deny_status      = optional(number)
    priority         = optional(number)
    preview          = optional(bool)
    opt_in_rule_ids  = optional(list(string))
    opt_out_rule_ids = optional(list(string))
    exclusions = optional(list(object({
      target_rule_ids = optional(list(string))
      request_headers = optional(list(object({
        operator = string
        value    = optional(string)
      })))
      request_cookies = optional(list(object({
        operator = string
        value    = optional(string)
      })))
      request_uris = optional(list(object({
        operator = string
        value    = optional(string)
      })))
      request_query_params = optional(list(object({
        operator = string
        value    = optional(string)
      })))
    })))
  }))
}

variable "waf_custom_rules" {
  description = "Customer-defined rules expressed in Cloud Armor's CEL rules language."
  type = map(object({
    expression  = string
    action      = optional(string)
    deny_status = optional(number)
    priority    = optional(number)
    preview     = optional(bool)
    description = optional(string)
    rate_limit = optional(object({
      threshold_count            = number
      interval_sec               = optional(number)
      exceed_status              = optional(number)
      enforce_on_key             = optional(string)
      enforce_on_key_name        = optional(string)
      ban_duration_sec           = optional(number)
      ban_threshold_count        = optional(number)
      ban_threshold_interval_sec = optional(number)
    }))
  }))
}

variable "waf_advanced_options" {
  description = "Policy-wide Cloud Armor options (request body parsing, logging verbosity, Adaptive Protection)."
  type = object({
    json_parsing                        = optional(string)
    json_content_types                  = optional(list(string))
    log_level                           = optional(string)
    user_ip_request_headers             = optional(list(string))
    adaptive_protection_enabled         = optional(bool)
    adaptive_protection_rule_visibility = optional(string)
  })
}
