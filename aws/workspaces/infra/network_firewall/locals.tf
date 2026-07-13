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

  # Map endpoints by firewall subnet id (stable) rather than AZ name/id strings, which
  # can differ between data.aws_availability_zones and firewall_status sync_states.
  firewall_endpoints_by_subnet = {
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.attachment[0].subnet_id => state.attachment[0].endpoint_id
  }

  firewall_endpoint_ids = [
    for subnet_id in var.firewall_subnet_ids : local.firewall_endpoints_by_subnet[subnet_id]
  ]
}
