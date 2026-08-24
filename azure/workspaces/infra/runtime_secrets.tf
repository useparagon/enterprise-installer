data "azurerm_client_config" "current" {}

locals {
  # Azure Key Vault names: 3-24 chars, alphanumeric and hyphens, must not end with
  # a hyphen. Truncating local.workspace to 24 chars can leave a trailing hyphen,
  # so strip any trailing hyphens after truncation.
  key_vault_name = replace(substr(local.workspace, 0, 24), "/-+$/", "")

  postgres_runtime = var.postgres_enabled ? module.postgres[0].postgres : null
  redis_runtime    = var.redis_enabled ? module.redis.redis : null
}

resource "azurerm_key_vault" "paragon" {
  name                       = local.key_vault_name
  location                   = var.location
  resource_group_name        = module.network.resource_group.name
  tenant_id                  = coalesce(var.azure_tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name                   = "premium"
  purge_protection_enabled   = var.key_vault_purge_protection_enabled
  soft_delete_retention_days = 90
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.paragon.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Set",
  ]
}

resource "azurerm_key_vault_secret" "runtime_postgres" {
  count = var.postgres_enabled ? 1 : 0

  name         = "postgres"
  key_vault_id = azurerm_key_vault.paragon.id
  value        = jsonencode(local.postgres_runtime)

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

# Same contract as output.redis / output.redis_managed (and legacy infra-output.json):
# - redis: Azure Cache for Redis when redis_enabled
# - redis-managed: Azure Managed Redis when redis_managed_enabled
# - coexistence: both secrets present; cutover: disable redis_enabled to remove the redis secret
resource "azurerm_key_vault_secret" "runtime_redis" {
  count = var.redis_enabled ? 1 : 0

  name         = "redis"
  key_vault_id = azurerm_key_vault.paragon.id
  value        = jsonencode(local.redis_runtime)

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "runtime_redis_managed" {
  count = var.redis_managed_enabled ? 1 : 0

  name         = "redis-managed"
  key_vault_id = azurerm_key_vault.paragon.id
  value        = jsonencode(module.redis_managed[0].redis)

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "runtime_storage" {
  name         = "storage"
  key_vault_id = azurerm_key_vault.paragon.id
  value = jsonencode({
    public_bucket               = module.storage.blob.public_container
    public_storage_account_name = module.storage.blob.public_storage_account_name
    private_bucket              = module.storage.blob.private_container
    managed_sync_bucket         = module.storage.blob.managed_sync_container
    logs_container              = module.storage.blob.logs_container
    auditlogs_container         = module.storage.blob.auditlogs_container
    root_user                   = module.storage.blob.name
    root_password               = module.storage.blob.access_key
  })

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "runtime_kafka" {
  count = var.managed_sync_enabled ? 1 : 0

  name         = "kafka"
  key_vault_id = azurerm_key_vault.paragon.id
  value = jsonencode({
    cluster_bootstrap_brokers = module.kafka[0].bootstrap_servers
    bootstrap_servers_private = module.kafka[0].bootstrap_servers_private
    namespace_name            = module.kafka[0].namespace_name
    cluster_username          = module.kafka[0].kafka_credentials.username
    cluster_password          = module.kafka[0].kafka_credentials.password
    cluster_mechanism         = module.kafka[0].kafka_credentials.mechanism
    cluster_tls_enabled       = module.kafka[0].tls_enabled
  })

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "runtime_bastion" {
  count = var.bastion_enabled ? 1 : 0

  name         = "bastion"
  key_vault_id = azurerm_key_vault.paragon.id
  value = jsonencode({
    public_dns  = module.bastion[0].connection.bastion_dns
    private_key = module.bastion[0].connection.private_key
  })

  depends_on = [azurerm_key_vault_access_policy.terraform]
}
