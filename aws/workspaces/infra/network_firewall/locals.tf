locals {
  nfw_log_prefix = "network-firewall"

  # STRICT_ORDER requires priority + stateful_default_actions and an engine options block;
  # DEFAULT_ACTION_ORDER forbids all three. Referenced rule groups must match this order.
  strict_order = var.network_firewall.stateful_rule_order == "STRICT_ORDER"

  stateful_rule_group_arns = [
    for arn in var.network_firewall.rule_group_arns : arn
    if can(regex(":stateful-rulegroup/", arn))
  ]

  stateless_rule_group_arns = [
    for arn in var.network_firewall.rule_group_arns : arn
    if can(regex(":stateless-rulegroup/", arn))
  ]

  log_destination = {
    bucketName = var.logs_bucket_name
    prefix     = local.nfw_log_prefix
  }

  firewall_endpoints_by_az = {
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  }

  firewall_endpoint_ids = [for az in var.availability_zones : local.firewall_endpoints_by_az[az]]
}
