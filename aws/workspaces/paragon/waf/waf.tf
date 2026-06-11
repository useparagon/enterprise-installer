resource "aws_wafv2_ip_set" "whitelist" {
  count = local.has_whitelist ? 1 : 0

  name               = "${var.workspace}-waf-whitelist"
  description        = "IPs that bypass WAF rules for ${var.workspace}"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.waf_ip_whitelist
}

resource "aws_wafv2_ip_set" "blacklist" {
  count = local.has_blacklist ? 1 : 0

  name               = "${var.workspace}-waf-blacklist"
  description        = "IPs that are always blocked for ${var.workspace}"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.waf_ip_blacklist
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.workspace}-waf"
  description = "Paragon enterprise WAF for ${var.workspace} public ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.has_whitelist ? [1] : []
    content {
      name     = "ip-whitelist"
      priority = 0

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.workspace}-waf-ip-whitelist"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.has_blacklist ? [1] : []
    content {
      name     = "ip-blacklist"
      priority = local.has_whitelist ? 1 : 0

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blacklist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.workspace}-waf-ip-blacklist"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.has_global_rate_limit ? [1] : []
    content {
      name     = "rate-limit-global"
      priority = local.ip_custom_rule_count

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit                 = var.waf_rate_limit_global
          aggregate_key_type    = "IP"
          evaluation_window_sec = var.waf_rate_limit_global_window_sec
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.workspace}-waf-rate-global"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.sorted_path_limits
    content {
      name     = "rate-limit-path-${replace(trimprefix(rule.value.path, "/"), "/", "-")}"
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit                 = rule.value.limit
          aggregate_key_type    = "IP"
          evaluation_window_sec = var.waf_rate_limit_path_window_sec

          scope_down_statement {
            byte_match_statement {
              search_string         = rule.value.path
              positional_constraint = "STARTS_WITH"

              field_to_match {
                uri_path {}
              }

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.workspace}-waf-rate-${replace(trimprefix(rule.value.path, "/"), "/", "-")}"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.managed_rules
    content {
      name     = rule.value.key
      priority = rule.value.priority

      dynamic "override_action" {
        for_each = rule.value.rule.override_action == "count" ? [1] : []
        content {
          count {}
        }
      }

      dynamic "override_action" {
        for_each = rule.value.rule.override_action == "none" ? [1] : []
        content {
          none {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.rule.name
          vendor_name = rule.value.rule.vendor_name

          dynamic "excluded_rule" {
            for_each = rule.value.rule.excluded_rules
            content {
              name = excluded_rule.value
            }
          }

          dynamic "rule_action_override" {
            for_each = rule.value.rule.rule_action_overrides
            content {
              name = rule_action_override.key

              action_to_use {
                dynamic "count" {
                  for_each = rule_action_override.value == "count" ? [1] : []
                  content {}
                }

                dynamic "block" {
                  for_each = rule_action_override.value == "block" ? [1] : []
                  content {}
                }

                dynamic "allow" {
                  for_each = rule_action_override.value == "allow" ? [1] : []
                  content {}
                }
              }
            }
          }

          dynamic "managed_rule_group_configs" {
            for_each = rule.value.rule.bot_control_inspection_level != null ? [1] : []
            content {
              aws_managed_rules_bot_control_rule_set {
                inspection_level = rule.value.rule.bot_control_inspection_level
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.workspace}-waf-${rule.value.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.workspace}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.workspace}-waf"
  }
}
