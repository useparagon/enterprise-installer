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

  has_whitelist = length(local.waf_ip_whitelist) > 0
  has_blacklist = length(local.waf_ip_blacklist) > 0

  has_global_rate_limit = var.waf_rate_limit_global != null && var.waf_rate_limit_global > 0

  ip_custom_rule_count = (local.has_whitelist ? 1 : 0) + (local.has_blacklist ? 1 : 0)

  sorted_path_limits = [
    for idx, path in sort(keys(var.waf_rate_limit_paths)) : {
      path     = startswith(path, "/") ? path : "/${path}"
      limit    = var.waf_rate_limit_paths[path]
      slug     = "path-${idx}"
      priority = local.ip_custom_rule_count + (local.has_global_rate_limit ? 1 : 0) + idx
    }
  ]

  rate_rule_count = (local.has_global_rate_limit ? 1 : 0) + length(local.sorted_path_limits)

  custom_rule_keys = sort(keys(var.waf_custom_rules))
  custom_rules = [
    for idx, key in local.custom_rule_keys : {
      key        = key
      priority   = coalesce(var.waf_custom_rules[key].priority, local.ip_custom_rule_count + local.rate_rule_count + idx)
      pattern    = var.waf_custom_rules[key].pattern
      action     = var.waf_custom_rules[key].action
      transforms = var.waf_custom_rules[key].transforms
    }
  ]

  managed_rules_offset = local.ip_custom_rule_count + local.rate_rule_count + length(local.custom_rules)

  managed_rule_keys = sort(keys(var.waf_managed_rule_groups))

  managed_rules = [
    for idx, key in local.managed_rule_keys : {
      key = key
      rule = {
        name                         = var.waf_managed_rule_groups[key].name
        vendor_name                  = coalesce(var.waf_managed_rule_groups[key].vendor_name, "AWS")
        override_action              = coalesce(var.waf_managed_rule_groups[key].override_action, "none")
        bot_control_inspection_level = var.waf_managed_rule_groups[key].bot_control_inspection_level
        rule_action_overrides = merge(
          {
            for name in coalesce(var.waf_managed_rule_groups[key].excluded_rules, []) :
            name => "count"
          },
          coalesce(var.waf_managed_rule_groups[key].rule_action_overrides, {})
        )
      }
      priority = coalesce(var.waf_managed_rule_groups[key].priority, local.managed_rules_offset + idx)
    }
  ]
  all_rule_priorities = concat(
    local.has_whitelist ? [0] : [],
    local.has_blacklist ? [local.has_whitelist ? 1 : 0] : [],
    local.has_global_rate_limit ? [local.ip_custom_rule_count] : [],
    [for item in local.sorted_path_limits : item.priority],
    [for item in local.custom_rules : item.priority],
    [for item in local.managed_rules : item.priority],
  )
}

check "managed_rule_priority_range" {
  assert {
    condition = alltrue([
      for key in local.managed_rule_keys :
      var.waf_managed_rule_groups[key].priority == null ? true : var.waf_managed_rule_groups[key].priority >= local.managed_rules_offset
    ])
    error_message = "Explicit waf_managed_rule_groups priority must be >= the number of IP and rate-limit rules to avoid collisions."
  }
}

check "managed_rule_priorities_unique" {
  assert {
    condition     = length(local.managed_rules) == length(distinct([for r in local.managed_rules : r.priority]))
    error_message = "waf_managed_rule_groups priorities must be unique within the Web ACL."
  }
}

check "all_rule_priorities_unique" {
  assert {
    condition     = length(local.all_rule_priorities) == length(distinct(local.all_rule_priorities))
    error_message = "AWS WAF rule priorities must be unique across IP, rate-limit, regex, and managed rules."
  }
}
