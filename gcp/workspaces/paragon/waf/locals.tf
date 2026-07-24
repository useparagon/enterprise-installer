locals {
  # Rules are evaluated from the lowest priority number up. Fixed bands leave room to
  # grow without renumbering neighbouring rules.
  priority_ip_allow      = 1000
  priority_ip_deny       = 2000
  priority_rate_path     = 3000
  priority_rate_global   = 4000
  priority_preconfigured = 5000
  priority_custom        = 6000
  priority_default       = 2147483647

  # A Cloud Armor rule accepts at most 10 source ranges, so long lists are split.
  src_ip_ranges_per_rule = 10

  waf_ip_whitelist = distinct([
    for raw in var.waf_ip_whitelist : local.normalized_cidrs[raw]
    if trimspace(raw) != ""
  ])

  waf_ip_blacklist = distinct([
    for raw in var.waf_ip_blacklist : local.normalized_cidrs[raw]
    if trimspace(raw) != ""
  ])

  # Bare addresses are accepted for convenience; Cloud Armor requires CIDR notation.
  normalized_cidrs = {
    for raw in distinct(concat(var.waf_ip_whitelist, var.waf_ip_blacklist)) :
    raw => strcontains(trimspace(raw), "/") ? trimspace(raw) : (
      strcontains(trimspace(raw), ":") ? "${trimspace(raw)}/128" : "${trimspace(raw)}/32"
    )
  }

  ip_allow_rules = [
    for idx, ranges in chunklist(local.waf_ip_whitelist, local.src_ip_ranges_per_rule) : {
      priority      = local.priority_ip_allow + idx
      src_ip_ranges = ranges
      slug          = "allow-${idx}"
    }
  ]

  ip_deny_rules = [
    for idx, ranges in chunklist(local.waf_ip_blacklist, local.src_ip_ranges_per_rule) : {
      priority      = local.priority_ip_deny + idx
      src_ip_ranges = ranges
      slug          = "deny-${idx}"
    }
  ]

  rate_limit_action         = coalesce(var.waf_rate_limit_options.action, "throttle")
  rate_limit_is_ban         = local.rate_limit_action == "rate_based_ban"
  rate_limit_exceed_action  = "deny(${coalesce(var.waf_rate_limit_options.exceed_status, 429)})"
  rate_limit_enforce_on_key = coalesce(var.waf_rate_limit_options.enforce_on_key, "IP")
  rate_limit_preview        = coalesce(var.waf_rate_limit_options.preview, false)
  rate_limit_ban_duration   = local.rate_limit_is_ban ? coalesce(var.waf_rate_limit_options.ban_duration_sec, 600) : null

  rate_limit_ban_threshold = local.rate_limit_is_ban && var.waf_rate_limit_options.ban_threshold_count != null ? [{
    count        = var.waf_rate_limit_options.ban_threshold_count
    interval_sec = coalesce(var.waf_rate_limit_options.ban_threshold_interval_sec, 600)
  }] : []

  has_global_rate_limit = var.waf_rate_limit_global != null && coalesce(var.waf_rate_limit_global, 0) > 0

  # Longest prefix first: Cloud Armor stops at the first match, so /api/foo must be
  # evaluated before /api. The length-encoded sort key keeps priorities stable.
  sorted_rate_limit_paths = [
    for entry in sort([
      for path in keys(var.waf_rate_limit_paths) :
      format("%06d|%s", 999999 - length(startswith(path, "/") ? path : "/${path}"), path)
    ]) : split("|", entry)[1]
  ]

  path_rate_rules = [
    for idx, path in local.sorted_rate_limit_paths : {
      priority   = local.priority_rate_path + idx
      slug       = "path-${idx}"
      path       = startswith(path, "/") ? path : "/${path}"
      threshold  = var.waf_rate_limit_paths[path]
      expression = "request.path.startsWith('${startswith(path, "/") ? path : "/${path}"}')"
    }
  ]

  preconfigured_rule_keys = sort(keys(var.waf_preconfigured_rules))

  # One evaluatePreconfiguredWaf() call expands to every signature in the rule set.
  preconfigured_rules = [
    for idx, key in local.preconfigured_rule_keys : {
      key        = key
      rule_set   = var.waf_preconfigured_rules[key].rule_set
      priority   = coalesce(var.waf_preconfigured_rules[key].priority, local.priority_preconfigured + idx)
      action     = "deny(${coalesce(var.waf_preconfigured_rules[key].deny_status, 403)})"
      preview    = coalesce(var.waf_preconfigured_rules[key].preview, false)
      exclusions = coalesce(var.waf_preconfigured_rules[key].exclusions, [])
      expression = "evaluatePreconfiguredWaf('${var.waf_preconfigured_rules[key].rule_set}', {${join(", ", concat(
        ["'sensitivity': ${coalesce(var.waf_preconfigured_rules[key].sensitivity, 1)}"],
        length(coalesce(var.waf_preconfigured_rules[key].opt_in_rule_ids, [])) > 0 ? ["'opt_in_rule_ids': [${join(", ", [for id in var.waf_preconfigured_rules[key].opt_in_rule_ids : "'${id}'"])}]"] : [],
        length(coalesce(var.waf_preconfigured_rules[key].opt_out_rule_ids, [])) > 0 ? ["'opt_out_rule_ids': [${join(", ", [for id in var.waf_preconfigured_rules[key].opt_out_rule_ids : "'${id}'"])}]"] : [],
      ))}})"
    }
  ]

  custom_rule_keys = sort(keys(var.waf_custom_rules))

  # Split by rate limiting so each collection stays a homogeneous object type.
  custom_rules_plain = [
    for idx, key in local.custom_rule_keys : {
      key         = key
      priority    = coalesce(var.waf_custom_rules[key].priority, local.priority_custom + idx)
      expression  = var.waf_custom_rules[key].expression
      preview     = coalesce(var.waf_custom_rules[key].preview, false)
      description = substr(coalesce(var.waf_custom_rules[key].description, key), 0, 63)
      action = coalesce(var.waf_custom_rules[key].action, "deny") == "allow" ? "allow" : (
        "deny(${coalesce(var.waf_custom_rules[key].deny_status, 403)})"
      )
    }
    if var.waf_custom_rules[key].rate_limit == null
  ]

  custom_rules_rate_limited = [
    for idx, key in local.custom_rule_keys : {
      key         = key
      priority    = coalesce(var.waf_custom_rules[key].priority, local.priority_custom + idx)
      expression  = var.waf_custom_rules[key].expression
      preview     = coalesce(var.waf_custom_rules[key].preview, false)
      description = substr(coalesce(var.waf_custom_rules[key].description, key), 0, 63)
      action      = coalesce(var.waf_custom_rules[key].action, "throttle")
      rate_limit = {
        threshold_count     = var.waf_custom_rules[key].rate_limit.threshold_count
        interval_sec        = coalesce(var.waf_custom_rules[key].rate_limit.interval_sec, 60)
        exceed_action       = "deny(${coalesce(var.waf_custom_rules[key].rate_limit.exceed_status, 429)})"
        enforce_on_key      = coalesce(var.waf_custom_rules[key].rate_limit.enforce_on_key, "IP")
        enforce_on_key_name = var.waf_custom_rules[key].rate_limit.enforce_on_key_name
        ban_duration_sec = coalesce(var.waf_custom_rules[key].action, "throttle") == "rate_based_ban" ? coalesce(
          var.waf_custom_rules[key].rate_limit.ban_duration_sec, 600
        ) : null
        ban_threshold = coalesce(var.waf_custom_rules[key].action, "throttle") == "rate_based_ban" && var.waf_custom_rules[key].rate_limit.ban_threshold_count != null ? [{
          count        = var.waf_custom_rules[key].rate_limit.ban_threshold_count
          interval_sec = coalesce(var.waf_custom_rules[key].rate_limit.ban_threshold_interval_sec, 600)
        }] : []
      }
    }
    if var.waf_custom_rules[key].rate_limit != null
  ]

  adaptive_protection_enabled = coalesce(var.waf_advanced_options.adaptive_protection_enabled, false)
  json_parsing                = coalesce(var.waf_advanced_options.json_parsing, "DISABLED")
  json_content_types          = coalesce(var.waf_advanced_options.json_content_types, [])
  user_ip_request_headers     = coalesce(var.waf_advanced_options.user_ip_request_headers, [])

  all_priorities = concat(
    [for rule in local.ip_allow_rules : rule.priority],
    [for rule in local.ip_deny_rules : rule.priority],
    [for rule in local.path_rate_rules : rule.priority],
    local.has_global_rate_limit ? [local.priority_rate_global] : [],
    [for rule in local.preconfigured_rules : rule.priority],
    [for rule in local.custom_rules_plain : rule.priority],
    [for rule in local.custom_rules_rate_limited : rule.priority],
    [local.priority_default],
  )
}

# Long IP lists are the usual cause of overflow, being chunked 10 CIDRs at a time.
check "rule_count_within_default_quota" {
  assert {
    condition     = length(local.all_priorities) <= 200
    error_message = "The Cloud Armor policy has ${length(local.all_priorities)} rules, above the default quota of 200 rules per security policy. Consolidate CIDRs into wider ranges or request a quota increase before applying."
  }
}
