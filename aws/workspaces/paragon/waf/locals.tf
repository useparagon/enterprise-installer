locals {
  waf_ip_whitelist = distinct([
    for value in split(",", var.waf_ip_whitelist) :
    "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}"
    if trimspace(value) != ""
  ])

  waf_ip_blacklist = distinct([
    for value in split(",", var.waf_ip_blacklist) :
    "${trimspace(value)}${replace(value, "/", "") != value ? "" : "/32"}"
    if trimspace(value) != ""
  ])

  has_whitelist = length(local.waf_ip_whitelist) > 0
  has_blacklist = length(local.waf_ip_blacklist) > 0

  has_global_rate_limit = var.waf_rate_limit_global != null

  sorted_path_limits = [
    for idx, path in sort(keys(var.waf_rate_limit_paths)) : {
      path     = path
      limit    = var.waf_rate_limit_paths[path]
      priority = local.ip_custom_rule_count + (local.has_global_rate_limit ? 1 : 0) + idx
    }
  ]

  ip_custom_rule_count = (local.has_whitelist ? 1 : 0) + (local.has_blacklist ? 1 : 0)

  rate_rule_count = (local.has_global_rate_limit ? 1 : 0) + length(local.sorted_path_limits)

  managed_rules_offset = local.ip_custom_rule_count + local.rate_rule_count

  managed_rule_keys = sort(keys(var.waf_managed_rule_groups))

  managed_rules = [
    for idx, key in local.managed_rule_keys : {
      key = key
      rule = merge(var.waf_managed_rule_groups[key], {
        # excluded_rules is legacy AWS API — provider only supports rule_action_override
        rule_action_overrides = merge(
          {
            for name in coalesce(var.waf_managed_rule_groups[key].excluded_rules, []) :
            name => "count"
          },
          coalesce(var.waf_managed_rule_groups[key].rule_action_overrides, {})
        )
      })
      priority = coalesce(var.waf_managed_rule_groups[key].priority, local.managed_rules_offset + idx)
    }
  ]
}
