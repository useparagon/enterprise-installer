# Azure Monitor cannot send diagnostics to Premium storage accounts.
locals {
  agc_dedicated_storage      = var.agc_diagnostics_enabled && var.storage_account_tier == "Premium"
  agc_diagnostics_account    = local.agc_dedicated_storage ? azurerm_storage_account.agc_diagnostics[0].name : azurerm_storage_account.blob.name
  agc_diagnostics_storage_id = local.agc_dedicated_storage ? azurerm_storage_account.agc_diagnostics[0].id : azurerm_storage_account.blob.id
}

resource "azurerm_storage_account" "agc_diagnostics" {
  count = local.agc_dedicated_storage ? 1 : 0

  name                            = "${substr(local.storage_account_name, 0, 21)}agc"
  resource_group_name             = var.resource_group.name
  location                        = var.resource_group.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = merge(var.tags, { Name = "${substr(local.storage_account_name, 0, 21)}agc" })
}

resource "azurerm_storage_account_network_rules" "agc_diagnostics" {
  count = local.agc_dedicated_storage ? 1 : 0

  storage_account_id = azurerm_storage_account.agc_diagnostics[0].id
  default_action     = "Deny"
  bypass             = ["AzureServices"]
}

# Scope lifecycle deletion to Azure Monitor's AGC log containers only.
resource "azurerm_storage_management_policy" "agc_logs" {
  count = var.agc_diagnostics_enabled && var.agc_logs_retention_days != null ? 1 : 0

  storage_account_id = local.agc_diagnostics_storage_id

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
