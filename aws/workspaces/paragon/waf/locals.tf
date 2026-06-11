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

  rate_global_priority = (local.has_whitelist ? 1 : 0) + (local.has_blacklist ? 1 : 0)

  sorted_path_limits = [
    for path in sort(keys(var.waf_rate_limit_paths)) : {
      path  = path
      limit = var.waf_rate_limit_paths[path]
    }
  ]

  path_rate_priorities = {
    for idx, item in local.sorted_path_limits :
    item.path => local.rate_global_priority + 1 + idx
  }

  managed_rules_offset = local.rate_global_priority + 1 + length(local.sorted_path_limits)

  ip_reputation_priority = var.waf_ip_reputation_enabled ? local.managed_rules_offset : -1
  bot_control_priority   = var.waf_bot_control_enabled ? local.managed_rules_offset + (var.waf_ip_reputation_enabled ? 1 : 0) : -1
}
