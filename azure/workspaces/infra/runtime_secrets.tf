data "azurerm_client_config" "current" {}

locals {
  # Azure Key Vault names: 3-24 chars, alphanumeric and hyphens, must not end with
  # a hyphen. Truncating local.workspace to 24 chars can leave a trailing hyphen,
  # so strip any trailing hyphens after truncation.
  key_vault_name = replace(substr(local.workspace, 0, 24), "/-+$/", "")
}

resource "azurerm_key_vault" "paragon" {
  name                       = local.key_vault_name
  location                   = var.location
  resource_group_name        = module.network.resource_group.name
  tenant_id                  = coalesce(var.azure_tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name                   = "premium"
  soft_delete_retention_days = 7
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
  name         = "postgres"
  key_vault_id = azurerm_key_vault.paragon.id
  value        = jsonencode(module.postgres.postgres)

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "runtime_redis" {
  name         = "redis"
  key_vault_id = azurerm_key_vault.paragon.id
  value        = jsonencode(module.redis.redis)

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
    microservice_user           = module.storage.blob.minio_microservice_user
    microservice_pass           = module.storage.blob.minio_microservice_pass
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
  name         = "bastion"
  key_vault_id = azurerm_key_vault.paragon.id
  value = jsonencode({
    public_dns  = module.bastion.connection.bastion_dns
    private_key = module.bastion.connection.private_key
  })

  depends_on = [azurerm_key_vault_access_policy.terraform]
}
