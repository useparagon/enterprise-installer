# Use infra's Standard diagnostics account (shared or dedicated for Premium).
data "azurerm_storage_account" "diagnostics" {
  count = var.enabled ? 1 : 0

  name                = var.diagnostics_storage_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_monitor_diagnostic_setting" "agc" {
  count = var.enabled ? 1 : 0

  name               = "${var.workspace}-agc-diagnostics"
  target_resource_id = azurerm_application_load_balancer.this[0].id
  storage_account_id = data.azurerm_storage_account.diagnostics[0].id

  lifecycle {
    precondition {
      condition     = data.azurerm_storage_account.diagnostics[0].account_tier == "Standard"
      error_message = "AGC diagnostics require a Standard Storage Account. Apply the infra workspace first."
    }
  }

  enabled_log {
    category = "TrafficControllerAccessLog"
  }

  enabled_log {
    category = "TrafficControllerFirewallLog"
  }
}
