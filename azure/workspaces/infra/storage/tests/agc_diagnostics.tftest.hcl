mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  workspace                  = "paragon-test"
  resource_group             = { name = "paragon-test-rg", location = "westus3" }
  virtual_network_subnet_ids = []
  tags                       = {}
  managed_sync_enabled       = false
  agent_os_enabled           = false
  agc_diagnostics_enabled    = true
  agc_logs_retention_days    = 30
  auditlogs_retention_days   = 30
  auditlogs_lock_enabled     = false
}

run "standard_reuses_main_storage" {
  command = plan

  variables {
    storage_account_tier = "Standard"
  }

  assert {
    condition     = length(azurerm_storage_account.agc_diagnostics) == 0
    error_message = "Standard accounts must not provision extra diagnostics storage."
  }

  assert {
    condition     = local.agc_dedicated_storage == false
    error_message = "AGC diagnostics should use the existing Standard account."
  }

  assert {
    condition     = length(azurerm_storage_management_policy.agc_logs) == 1
    error_message = "AGC logs should retain the lifecycle policy."
  }
}

run "premium_uses_dedicated_standard_storage" {
  command = plan

  variables {
    storage_account_tier = "Premium"
  }

  assert {
    condition = (
      length(azurerm_storage_account.agc_diagnostics) == 1 &&
      azurerm_storage_account.agc_diagnostics[0].account_tier == "Standard" &&
      azurerm_storage_account.agc_diagnostics[0].account_kind == "StorageV2"
    )
    error_message = "Premium application storage requires a dedicated Standard StorageV2 account."
  }

  assert {
    condition     = local.agc_dedicated_storage == true
    error_message = "Premium AGC diagnostics must select the dedicated Standard account."
  }

  assert {
    condition     = azurerm_storage_account_network_rules.agc_diagnostics[0].default_action == "Deny"
    error_message = "Dedicated diagnostic storage must not allow unrestricted network access."
  }
}

run "no_agc_no_diagnostics_storage" {
  command = plan

  variables {
    storage_account_tier    = "Premium"
    agc_diagnostics_enabled = false
    agc_logs_retention_days = null
  }

  assert {
    condition = (
      length(azurerm_storage_account.agc_diagnostics) == 0 &&
      length(azurerm_storage_management_policy.agc_logs) == 0
    )
    error_message = "AGC-disabled installations must not create diagnostic storage."
  }
}

run "no_retention_still_creates_diagnostics_account" {
  command = plan

  variables {
    storage_account_tier    = "Premium"
    agc_logs_retention_days = null
  }

  assert {
    condition = (
      length(azurerm_storage_account.agc_diagnostics) == 1 &&
      length(azurerm_storage_management_policy.agc_logs) == 0
    )
    error_message = "Disabling lifecycle retention must not disable AGC diagnostics."
  }
}
