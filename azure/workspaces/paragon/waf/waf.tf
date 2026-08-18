data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  waf_policy_name = "${var.workspace}-waf"
  custom_rules = concat(
    local.has_whitelist ? [local.whitelist_rule] : [],
    local.has_blacklist ? [local.blacklist_rule] : [],
    local.has_global_rate_limit ? [local.global_rate_rule] : [],
    local.path_rate_rules,
  )
}

resource "azurerm_web_application_firewall_policy" "this" {
  name                = local.waf_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location

  policy_settings {
    enabled                          = true
    mode                             = var.waf_mode
    request_body_check               = true
    max_request_body_size_in_kb      = var.waf_max_request_body_size_kb
    request_body_inspect_limit_in_kb = var.waf_max_request_body_size_kb
    file_upload_limit_in_mb          = var.waf_file_upload_limit_mb
  }

  managed_rules {
    dynamic "managed_rule_set" {
      for_each = var.waf_managed_rule_sets

      content {
        type    = managed_rule_set.value.type
        version = managed_rule_set.value.version

        dynamic "rule_group_override" {
          for_each = try(managed_rule_set.value.rule_group_overrides, {})

          content {
            rule_group_name = rule_group_override.value.rule_group_name

            dynamic "rule" {
              for_each = try(rule_group_override.value.rules, [])

              content {
                id      = rule.value.id
                enabled = try(rule.value.enabled, null)
                action  = try(rule.value.action, null)
              }
            }
          }
        }
      }
    }
  }

  dynamic "custom_rules" {
    for_each = { for rule in local.custom_rules : rule.name => rule }

    content {
      name                 = custom_rules.value.name
      priority             = custom_rules.value.priority
      rule_type            = custom_rules.value.ruleType
      action               = custom_rules.value.action
      enabled              = custom_rules.value.state == "Enabled"
      rate_limit_duration  = try(custom_rules.value.rateLimitDuration, null)
      rate_limit_threshold = try(custom_rules.value.rateLimitThreshold, null)
      group_rate_limit_by  = try(custom_rules.value.groupByUserSession[0].groupByVariables[0].variableName, null)

      dynamic "match_conditions" {
        for_each = custom_rules.value.matchConditions

        content {
          operator           = match_conditions.value.operator
          match_values       = match_conditions.value.matchValues
          negation_condition = try(match_conditions.value.negationCondition, false)

          dynamic "match_variables" {
            for_each = match_conditions.value.matchVariables

            content {
              variable_name = match_variables.value.variableName
            }
          }
        }
      }
    }
  }

  tags = {
    Name = local.waf_policy_name
  }
}
