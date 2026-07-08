resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.workspace}-network-firewall-policy"

  firewall_policy {
    stateless_default_actions          = var.network_firewall.stateless_default_actions
    stateless_fragment_default_actions = var.network_firewall.stateless_fragment_default_actions

    dynamic "stateful_rule_group_reference" {
      for_each = local.stateful_rule_group_arns
      content {
        resource_arn = stateful_rule_group_reference.value
        priority     = stateful_rule_group_reference.key + 1
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
