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

variable "waf_managed_rule_sets" {
  type = map(object({
    type    = string
    version = string
    action  = optional(string)
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
      path     = startswith(path, "/") ? path : "/${path}"
      limit    = var.waf_rate_limit_paths[path]
      slug     = replace(replace(startswith(path, "/") ? substr(path, 1, length(path) - 1) : path, "/", "-"), ".", "-")
      priority = local.ip_custom_rule_count + (local.has_global_rate_limit ? 1 : 0) + idx + 1
    }
  ]

  whitelist_rule = {
    name     = "ip-whitelist"
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
    name     = "ip-blacklist"
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
    name               = "rate-limit-global"
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
      name               = "rate-limit-${item.slug}"
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
}
