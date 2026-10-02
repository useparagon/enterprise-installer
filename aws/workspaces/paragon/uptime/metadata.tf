locals {
  # Shared HTML dashboard (health-checker `/`); attached to every monitor when health-checker is monitored.
  health_checker_status_page_url = local.enabled && contains(keys(var.microservices), "health-checker") ? var.microservices["health-checker"].public_url : null
}

resource "betteruptime_metadata" "status_page" {
  for_each = local.health_checker_status_page_url != null ? var.microservices : {}

  owner_id   = betteruptime_monitor.monitor[each.key].id
  owner_type = "Monitor"
  key        = "Status Page"

  metadata_value {
    type  = "String"
    value = local.health_checker_status_page_url
  }
}
