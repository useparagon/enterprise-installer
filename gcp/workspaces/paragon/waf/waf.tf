# Attached per backend service through a BackendConfig in the helm module, never by
# editing the Ingress controller's backend services directly.
resource "google_compute_security_policy" "this" {
  name        = "${var.workspace}-waf"
  description = "Paragon enterprise Cloud Armor policy for ${var.workspace} public ingress"
  type        = "CLOUD_ARMOR"

  advanced_options_config {
    json_parsing            = local.json_parsing
    log_level               = coalesce(var.waf_advanced_options.log_level, "NORMAL")
    user_ip_request_headers = local.user_ip_request_headers

    dynamic "json_custom_config" {
      for_each = local.json_parsing == "STANDARD" && length(local.json_content_types) > 0 ? [1] : []
      content {
        content_types = local.json_content_types
      }
    }
  }

  dynamic "adaptive_protection_config" {
    for_each = local.adaptive_protection_enabled ? [1] : []
    content {
      layer_7_ddos_defense_config {
        enable          = true
        rule_visibility = coalesce(var.waf_advanced_options.adaptive_protection_rule_visibility, "STANDARD")
      }
    }
  }

  dynamic "rule" {
    for_each = local.ip_allow_rules
    content {
      action      = "allow"
      priority    = rule.value.priority
      description = "paragon ip allowlist ${rule.value.slug}"
      preview     = false

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
    }
  }

  dynamic "rule" {
    for_each = local.ip_deny_rules
    content {
      action      = "deny(${var.waf_ip_blacklist_deny_status})"
      priority    = rule.value.priority
      description = "paragon ip denylist ${rule.value.slug}"
      preview     = false

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
    }
  }

  # Evaluated before the global limit so scanned routes can get a tighter budget.
  dynamic "rule" {
    for_each = local.path_rate_rules
    content {
      action      = local.rate_limit_action
      priority    = rule.value.priority
      description = "paragon rate limit ${rule.value.slug}"
      preview     = local.rate_limit_preview

      match {
        expr {
          expression = rule.value.expression
        }
      }

      rate_limit_options {
        conform_action      = "allow"
        exceed_action       = local.rate_limit_exceed_action
        enforce_on_key      = local.rate_limit_enforce_on_key
        enforce_on_key_name = var.waf_rate_limit_options.enforce_on_key_name
        ban_duration_sec    = local.rate_limit_ban_duration

        rate_limit_threshold {
          count        = rule.value.threshold
          interval_sec = var.waf_rate_limit_path_window_sec
        }

        dynamic "ban_threshold" {
          for_each = local.rate_limit_ban_threshold
          content {
            count        = ban_threshold.value.count
            interval_sec = ban_threshold.value.interval_sec
          }
        }
      }
    }
  }

  dynamic "rule" {
    for_each = local.has_global_rate_limit ? [1] : []
    content {
      action      = local.rate_limit_action
      priority    = local.priority_rate_global
      description = "paragon rate limit global"
      preview     = local.rate_limit_preview

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }

      rate_limit_options {
        conform_action      = "allow"
        exceed_action       = local.rate_limit_exceed_action
        enforce_on_key      = local.rate_limit_enforce_on_key
        enforce_on_key_name = var.waf_rate_limit_options.enforce_on_key_name
        ban_duration_sec    = local.rate_limit_ban_duration

        rate_limit_threshold {
          count        = var.waf_rate_limit_global
          interval_sec = var.waf_rate_limit_global_window_sec
        }

        dynamic "ban_threshold" {
          for_each = local.rate_limit_ban_threshold
          content {
            count        = ban_threshold.value.count
            interval_sec = ban_threshold.value.interval_sec
          }
        }
      }
    }
  }

  dynamic "rule" {
    for_each = local.preconfigured_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = substr("paragon waf ${rule.value.key}", 0, 63)
      preview     = rule.value.preview

      match {
        expr {
          expression = rule.value.expression
        }
      }

      dynamic "preconfigured_waf_config" {
        for_each = length(rule.value.exclusions) > 0 ? [1] : []
        content {
          dynamic "exclusion" {
            for_each = rule.value.exclusions
            content {
              target_rule_set = rule.value.rule_set
              target_rule_ids = coalesce(exclusion.value.target_rule_ids, [])

              dynamic "request_header" {
                for_each = coalesce(exclusion.value.request_headers, [])
                content {
                  operator = request_header.value.operator
                  value    = request_header.value.value
                }
              }

              dynamic "request_cookie" {
                for_each = coalesce(exclusion.value.request_cookies, [])
                content {
                  operator = request_cookie.value.operator
                  value    = request_cookie.value.value
                }
              }

              dynamic "request_uri" {
                for_each = coalesce(exclusion.value.request_uris, [])
                content {
                  operator = request_uri.value.operator
                  value    = request_uri.value.value
                }
              }

              dynamic "request_query_param" {
                for_each = coalesce(exclusion.value.request_query_params, [])
                content {
                  operator = request_query_param.value.operator
                  value    = request_query_param.value.value
                }
              }
            }
          }
        }
      }
    }
  }

  dynamic "rule" {
    for_each = local.custom_rules_plain
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview

      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }

  dynamic "rule" {
    for_each = local.custom_rules_rate_limited
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview

      match {
        expr {
          expression = rule.value.expression
        }
      }

      rate_limit_options {
        conform_action      = "allow"
        exceed_action       = rule.value.rate_limit.exceed_action
        enforce_on_key      = rule.value.rate_limit.enforce_on_key
        enforce_on_key_name = rule.value.rate_limit.enforce_on_key_name
        ban_duration_sec    = rule.value.rate_limit.ban_duration_sec

        rate_limit_threshold {
          count        = rule.value.rate_limit.threshold_count
          interval_sec = rule.value.rate_limit.interval_sec
        }

        dynamic "ban_threshold" {
          for_each = rule.value.rate_limit.ban_threshold
          content {
            count        = ban_threshold.value.count
            interval_sec = ban_threshold.value.interval_sec
          }
        }
      }
    }
  }

  # Cloud Armor requires a catch-all rule at the maximum priority.
  rule {
    action      = "allow"
    priority    = local.priority_default
    description = "paragon default allow"
    preview     = false

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.all_priorities) == length(distinct(local.all_priorities))
      error_message = "Cloud Armor rule priorities must be unique. Check the explicit `priority` values in waf_preconfigured_rules and waf_custom_rules against the reserved bands documented in gcp/workspaces/paragon/README.md."
    }
  }
}
