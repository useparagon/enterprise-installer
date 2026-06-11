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

  rule {
    name     = "rate-limit-global"
    priority = local.rate_global_priority

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

  dynamic "rule" {
    for_each = local.sorted_path_limits
    content {
      name     = "rate-limit-path-${replace(trimprefix(rule.value.path, "/"), "/", "-")}"
      priority = local.path_rate_priorities[rule.value.path]

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
    for_each = var.waf_ip_reputation_enabled ? [1] : []
    content {
      name     = "aws-managed-ip-reputation"
      priority = local.ip_reputation_priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.workspace}-waf-ip-reputation"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.waf_bot_control_enabled ? [1] : []
    content {
      name     = "aws-managed-bot-control"
      priority = local.bot_control_priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesBotControlRuleSet"
          vendor_name = "AWS"

          managed_rule_group_configs {
            aws_managed_rules_bot_control_rule_set {
              inspection_level = "COMMON"
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.workspace}-waf-bot-control"
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
