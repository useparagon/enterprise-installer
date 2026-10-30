mock_provider "azurerm" {}

run "regex_patterns_and_priorities" {
  command = plan

  variables {
    workspace                      = "waf-test"
    resource_group_name            = "rg-waf-test"
    location                       = "eastus2"
    waf_mode                       = "Prevention"
    waf_ip_whitelist               = ["198.51.100.1"]
    waf_ip_blacklist               = ["203.0.113.2"]
    waf_rate_limit_global          = 600
    waf_rate_limit_global_duration = "FiveMins"
    waf_rate_limit_paths           = { "/api/" = 200 }
    waf_rate_limit_path_duration   = "FiveMins"
    waf_rate_limit_group_by        = "ClientAddr"
    waf_max_request_body_size_kb   = 2000
    waf_file_upload_limit_mb       = 100
    waf_managed_rule_sets = {
      drs = {
        type    = "Microsoft_DefaultRuleSet"
        version = "2.1"
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
    condition     = length(local.regex_rules) == 3
    error_message = "Expected three Azure WAF regex rules."
  }

  assert {
    condition     = length(local.all_custom_rule_priorities) == length(distinct(local.all_custom_rule_priorities))
    error_message = "Azure WAF priorities must not overlap."
  }

  assert {
    condition     = length([for item in azurerm_web_application_firewall_policy.this.custom_rules : item if startswith(item.name, "regex")]) == 3
    error_message = "All three regex rules must be rendered in the Azure WAF policy."
  }

  # Azure rejects dashes in custom-rule names; cover IP, rate and regex generators.
  assert {
    condition = (
      length(azurerm_web_application_firewall_policy.this.custom_rules) == 7 &&
      alltrue([
        for item in azurerm_web_application_firewall_policy.this.custom_rules :
        can(regex("^[A-Za-z0-9]{1,128}$", item.name))
      ]) &&
      length(distinct([for item in azurerm_web_application_firewall_policy.this.custom_rules : item.name])) == 7
    )
    error_message = "All seven WAF custom rules must have unique, Azure-compatible alphanumeric names."
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
