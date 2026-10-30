# Scope lifecycle deletion to Azure Monitor's AGC log containers only.
resource "azurerm_storage_management_policy" "agc_logs" {
  count = var.agc_logs_retention_days != null ? 1 : 0

  storage_account_id = azurerm_storage_account.blob.id

  rule {
    name    = "agcAccessFirewallLogs"
    enabled = true

    filters {
      blob_types = ["appendBlob", "blockBlob"]
      prefix_match = [
        "insights-logs-trafficcontrolleraccesslog/",
        "insights-logs-trafficcontrollerfirewalllog/",
      ]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.agc_logs_retention_days
      }
    }
  }
}
