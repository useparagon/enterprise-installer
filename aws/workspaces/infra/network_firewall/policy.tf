resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.workspace}-network-firewall-policy"

  firewall_policy {
    stateless_default_actions          = var.network_firewall.stateless_default_actions
    stateless_fragment_default_actions = var.network_firewall.stateless_fragment_default_actions

    dynamic "stateful_engine_options" {
      for_each = local.strict_order ? [1] : []
      content {
        rule_order = "STRICT_ORDER"
      }
    }

    # Only valid (and required) with STRICT_ORDER; omitted for DEFAULT_ACTION_ORDER.
    stateful_default_actions = local.strict_order ? var.network_firewall.stateful_default_actions : null

    dynamic "stateful_rule_group_reference" {
      for_each = local.stateful_rule_group_arns
      content {
        resource_arn = stateful_rule_group_reference.value
        priority     = local.strict_order ? stateful_rule_group_reference.key + 1 : null
      }
    }

    dynamic "stateless_rule_group_reference" {
      for_each = local.stateless_rule_group_arns
      content {
        resource_arn = stateless_rule_group_reference.value
        priority     = stateless_rule_group_reference.key + 1
      }
    }
  }

  tags = {
    Name = "${var.workspace}-network-firewall-policy"
  }
}
