resource "betteruptime_monitor_group" "group" {
  count = local.enabled ? 1 : 0

  name   = var.uptime_company
  paused = true

  lifecycle {
    ignore_changes = [paused]
  }
}

data "betteruptime_policy" "escalation" {
  count = local.enabled ? 1 : 0

  name = var.uptime_policy
}

resource "betteruptime_monitor" "monitor" {
  for_each = local.enabled ? var.microservices : {}

  pronounceable_name = "Enterprise ${var.uptime_company} - Microservice ${each.key}"

  check_frequency       = 30
  confirmation_period   = 120
  domain_expiration     = 14
  expected_status_codes = [200]
  maintenance_timezone  = "Pacific Time (US & Canada)"
  monitor_group_id      = betteruptime_monitor_group.group[0].id
  monitor_type          = "expected_status_code"
  policy_id             = data.betteruptime_policy.escalation[0].id
  recovery_period       = 60
  regions               = var.uptime_regions
  request_timeout       = 15
  ssl_expiration        = 14
  team_wait             = 180
  url                   = "${each.value.public_url}${coalesce(try(each.value.monitor_path, null), each.value.healthcheck_path)}"

  call  = true
  email = true
  push  = true
  sms   = true

  paused = true

  lifecycle {
    ignore_changes = [paused]
  }
}
