data "azurerm_resource_group" "infra" {
  count = local.use_legacy_infra_json ? 0 : 1
  name  = local.resource_group_name
}

data "azurerm_key_vault" "paragon" {
  count               = local.use_legacy_infra_json ? 0 : 1
  name                = substr(local.workspace, 0, 24)
  resource_group_name = data.azurerm_resource_group.infra[0].name
}

data "azurerm_key_vault_secret" "infra_postgres" {
  count        = local.use_legacy_infra_json ? 0 : 1
  name         = "postgres"
  key_vault_id = data.azurerm_key_vault.paragon[0].id
}

data "azurerm_key_vault_secret" "infra_redis" {
  count        = local.use_legacy_infra_json ? 0 : 1
  name         = "redis"
  key_vault_id = data.azurerm_key_vault.paragon[0].id
}

data "azurerm_key_vault_secret" "infra_storage" {
  count        = local.use_legacy_infra_json ? 0 : 1
  name         = "storage"
  key_vault_id = data.azurerm_key_vault.paragon[0].id
}

data "azurerm_key_vault_secret" "infra_kafka" {
  count        = local.use_legacy_infra_json ? 0 : (var.managed_sync_enabled ? 1 : 0)
  name         = "kafka"
  key_vault_id = data.azurerm_key_vault.paragon[0].id
}

locals {
  provider_infra_vars = merge(
    {
      workspace        = { value = local.workspace }
      cluster_name     = { value = local.cluster_name }
      logs_bucket      = { value = local.logs_bucket }
      auditlogs_bucket = { value = local.auditlogs_bucket }
      resource_group = {
        value = {
          name     = data.azurerm_resource_group.infra[0].name
          location = data.azurerm_resource_group.infra[0].location
        }
      }
      postgres = { value = jsondecode(data.azurerm_key_vault_secret.infra_postgres[0].value) }
      redis    = { value = jsondecode(data.azurerm_key_vault_secret.infra_redis[0].value) }
      minio    = { value = jsondecode(data.azurerm_key_vault_secret.infra_storage[0].value) }
    },
    var.managed_sync_enabled ? {
      kafka = { value = jsondecode(data.azurerm_key_vault_secret.infra_kafka[0].value) }
    } : {}
  )

  infra_vars = local.use_legacy_infra_json ? local.legacy_infra_vars : local.provider_infra_vars
}
