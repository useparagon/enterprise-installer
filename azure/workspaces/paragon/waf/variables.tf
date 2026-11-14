variable "tags" {
  description = "Tags applied to the WAF policy (workspace PascalCase)."
  type        = map(string)
  default     = {}
}

variable "workspace" {
  description = "Workspace prefix for WAF resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the WAF policy."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "waf_mode" {
  description = "Detection or Prevention."
  type        = string
}

variable "waf_ip_whitelist" {
  type = list(string)
}

variable "waf_ip_blacklist" {
  type = list(string)
}

variable "waf_rate_limit_global" {
  type     = number
  nullable = true
}

variable "waf_rate_limit_global_duration" {
  type = string
}

variable "waf_rate_limit_paths" {
  type = map(number)
}

variable "waf_rate_limit_path_duration" {
  type = string
}

variable "waf_rate_limit_group_by" {
  type = string
}

variable "waf_max_request_body_size_kb" {
  type = number
}

variable "waf_file_upload_limit_mb" {
  type = number
}


variable "waf_custom_rules" {
  description = "AGC WAF RequestUri regex rules with block, allow, or log actions and optional priorities and transforms."
  type = map(object({
    pattern    = string
    action     = optional(string, "block")
    priority   = optional(number)
    transforms = optional(list(string), ["URL_DECODE", "LOWERCASE"])
  }))
}

variable "waf_managed_rule_sets" {
  description = "Managed rule sets to attach. Optional rule_group_overrides map per-rule enabled/action (Allow, Block, Log, AnomalyScoring; JSChallenge only on Bot Manager)."
  type = map(object({
    type    = string
    version = string
    rule_group_overrides = optional(map(object({
      rule_group_name = string
      rules = optional(list(object({
        id      = string
        enabled = optional(bool)
        action  = optional(string)
      })), [])
    })), {})
  }))
}

locals {
  waf_ip_whitelist = distinct([
    for raw in var.waf_ip_whitelist :
    "${trimspace(raw)}${!strcontains(trimspace(raw), "/") ? "/32" : ""}"
    if trimspace(raw) != ""
  ])

  waf_ip_blacklist = distinct([
    for raw in var.waf_ip_blacklist :
    "${trimspace(raw)}${!strcontains(trimspace(raw), "/") ? "/32" : ""}"
    if trimspace(raw) != ""
  ])

  has_whitelist         = length(local.waf_ip_whitelist) > 0
  has_blacklist         = length(local.waf_ip_blacklist) > 0
  has_global_rate_limit = var.waf_rate_limit_global != null ? var.waf_rate_limit_global > 0 : false
  ip_custom_rule_count  = (local.has_whitelist ? 1 : 0) + (local.has_blacklist ? 1 : 0)

  sorted_path_limits = [
    for idx, path in sort(keys(var.waf_rate_limit_paths)) : {
      path  = startswith(path, "/") ? path : "/${path}"
      limit = var.waf_rate_limit_paths[path]
      # Azure custom rule names must be alphanumeric; keep a stable identifier per path.
      name     = "rateLimitPath${substr(md5(path), 0, 12)}"
      priority = local.ip_custom_rule_count + (local.has_global_rate_limit ? 1 : 0) + idx + 1
    }
  ]

  whitelist_rule = {
    name     = "ipWhitelist"
    priority = 1
    ruleType = "MatchRule"
    action   = "Allow"
    state    = "Enabled"
    matchConditions = [{
      matchVariables = [{ variableName = "RemoteAddr" }]
      operator       = "IPMatch"
      matchValues    = local.waf_ip_whitelist
    }]
  }

  blacklist_rule = {
    name     = "ipBlacklist"
    priority = local.has_whitelist ? 2 : 1
    ruleType = "MatchRule"
    action   = "Block"
    state    = "Enabled"
    matchConditions = [{
      matchVariables = [{ variableName = "RemoteAddr" }]
      operator       = "IPMatch"
      matchValues    = local.waf_ip_blacklist
    }]
  }

  global_rate_rule = {
    name               = "rateLimitGlobal"
    priority           = local.ip_custom_rule_count + 1
    ruleType           = "RateLimitRule"
    action             = "Block"
    state              = "Enabled"
    rateLimitDuration  = var.waf_rate_limit_global_duration
    rateLimitThreshold = var.waf_rate_limit_global
    groupByUserSession = [{
      groupByVariables = [{ variableName = var.waf_rate_limit_group_by }]
    }]
    matchConditions = [{
      matchVariables    = [{ variableName = "RemoteAddr" }]
      operator          = "IPMatch"
      negationCondition = true
      matchValues       = ["255.255.255.255/32"]
    }]
  }

  path_rate_rules = [
    for item in local.sorted_path_limits : {
      name               = item.name
      priority           = item.priority
      ruleType           = "RateLimitRule"
      action             = "Block"
      state              = "Enabled"
      rateLimitDuration  = var.waf_rate_limit_path_duration
      rateLimitThreshold = item.limit
      groupByUserSession = [{
        groupByVariables = [{ variableName = var.waf_rate_limit_group_by }]
      }]
      matchConditions = [{
        matchVariables = [{ variableName = "RequestUri" }]
        operator       = "BeginsWith"
        matchValues    = [item.path]
      }]
    }
  ]

  custom_rule_keys = sort(keys(var.waf_custom_rules))
  regex_rules = [
    for idx, key in local.custom_rule_keys : {
      name     = "regex${join("", [for part in split("-", key) : title(part)])}"
      priority = coalesce(var.waf_custom_rules[key].priority, local.ip_custom_rule_count + (local.has_global_rate_limit ? 1 : 0) + length(local.sorted_path_limits) + idx + 1)
      ruleType = "MatchRule"
      action   = { block = "Block", allow = "Allow", log = "Log" }[var.waf_custom_rules[key].action]
      state    = "Enabled"
      matchConditions = [{
        matchVariables = [{ variableName = "RequestUri" }]
        operator       = "Regex"
        matchValues    = [var.waf_custom_rules[key].pattern]
        transforms     = [for transform in var.waf_custom_rules[key].transforms : { URL_DECODE = "UrlDecode", LOWERCASE = "Lowercase" }[transform] if transform != "NONE"]
      }]
    }
  ]

  all_custom_rule_priorities = concat(
    local.has_whitelist ? [1] : [],
    local.has_blacklist ? [local.has_whitelist ? 2 : 1] : [],
    local.has_global_rate_limit ? [local.ip_custom_rule_count + 1] : [],
    [for item in local.sorted_path_limits : item.priority],
    [for item in local.regex_rules : item.priority],
  )
}

check "custom_rule_priorities" {
  assert {
    condition = (
      length(local.all_custom_rule_priorities) <= 100 &&
      alltrue([for priority in local.all_custom_rule_priorities : priority >= 1 && priority <= 100]) &&
      length(local.all_custom_rule_priorities) == length(distinct(local.all_custom_rule_priorities))
    )
    error_message = "Azure WAF custom rule priorities must be unique integers from 1 to 100, including IP, rate limiting, and regex rules."
  }
}
