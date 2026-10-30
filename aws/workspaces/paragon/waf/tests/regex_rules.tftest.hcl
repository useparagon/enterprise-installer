mock_provider "aws" {}

run "regex_patterns_and_priorities" {
  command = plan

  variables {
    workspace                        = "waf-test"
    aws_region                       = "us-east-1"
    waf_logs_retention_days          = 7
    waf_ip_whitelist                 = []
    waf_ip_blacklist                 = []
    waf_rate_limit_global            = 600
    waf_rate_limit_global_window_sec = 300
    waf_rate_limit_paths             = {}
    waf_rate_limit_path_window_sec   = 300
    waf_managed_rule_groups = {
      common = {
        name = "AWSManagedRulesCommonRuleSet"
      }
    }
    waf_custom_rules = {
      block-php = {
        pattern = "\\.php([/?]|$)"
      }
      block-sensitive-dotfiles = {
        pattern = "(^|/)\\.(env|git|aws|svn|config)([/?.]|$)"
      }
      block-wordpress-probes = {
        pattern = "(^|/)(wp-admin|wp-content|wp-includes|wp-json|wordpress)(/|\\?|$)"
      }
    }
  }

  assert {
    condition     = length(local.custom_rules) == 3 && local.managed_rules_offset == 4
    error_message = "Expected three regex rules after the global rate limit and before the managed rules."
  }

  assert {
    condition     = length(local.all_rule_priorities) == length(distinct(local.all_rule_priorities))
    error_message = "AWS WAF priorities must not overlap."
  }

  assert {
    condition     = length([for item in aws_wafv2_web_acl.this.rule : item if startswith(item.name, "regex-")]) == 3
    error_message = "All three regex rules must be rendered in the AWS Web ACL."
  }

  # Unknown scanner paths should match, but real Paragon admin routes must remain accessible.
  assert {
    condition = (
      length(regexall(var.waf_custom_rules["block-php"].pattern, "/index.php")) > 0 &&
      length(regexall(var.waf_custom_rules["block-sensitive-dotfiles"].pattern, "/.env")) > 0 &&
      length(regexall(var.waf_custom_rules["block-wordpress-probes"].pattern, "/wp-json/batch/v1")) > 0 &&
      alltrue([
        for rule in values(var.waf_custom_rules) :
        length(regexall(rule.pattern, "/admin/projects/123/account-usage")) == 0
      ])
    )
    error_message = "Regex rules must match known scanner paths without matching Paragon /admin/projects APIs."
  }
}
