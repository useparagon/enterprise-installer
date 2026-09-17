data "azurerm_client_config" "current" {}

locals {
  # Azure Key Vault names: 3-24 chars, alphanumeric and hyphens, must not end with
  # a hyphen. Truncating local.workspace to 24 chars can leave a trailing hyphen,
  # so strip any trailing hyphens after truncation.
  key_vault_name = replace(substr(local.workspace, 0, 24), "/-+$/", "")

  postgres_runtime = var.postgres_enabled ? module.postgres[0].postgres : null
  redis_runtime    = var.redis_enabled ? module.redis.redis : null

  # Static map key "terraform" so a moved block can keep the existing singleton
  # policy in state. Extra principals are keyed by object id.
  key_vault_access_policies = merge(
    { terraform = data.azurerm_client_config.current.object_id },
    {
      for id in distinct(compact(var.key_vault_access_object_ids)) :
      id => id
      if id != data.azurerm_client_config.current.object_id
    },
  )
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
  for_each = local.key_vault_access_policies

  key_vault_id = azurerm_key_vault.paragon.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value

  secret_permissions = [
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Set",
  ]

  # Certificate Import/Get needed for ESO PushSecret (same SP as External Secrets).
  certificate_permissions = [
    "Create",
    "Delete",
    "Get",
    "Import",
    "List",
    "Update",
  ]
}

moved {
  from = azurerm_key_vault_access_policy.terraform
  to   = azurerm_key_vault_access_policy.terraform["terraform"]
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
  # Agent OS credentials have a dedicated app secret and must not leak into the
  # shared platform/Managed Sync handoff consumed by Helm and Hoop.
  value = jsonencode(var.redis_managed_enabled ? {
    for name, config in module.redis_managed[0].redis :
    name => config if name != "agent_os"
  } : null)

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

resource "azurerm_key_vault_secret" "runtime_agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name         = "agent-os"
  key_vault_id = azurerm_key_vault.paragon.id
  value = jsonencode({
    app_config         = local.agent_os_app_config
    admin_config       = local.agent_os_admin_config
    storage_account    = module.storage.blob.name
    storage_account_id = module.storage.blob.id
    container          = module.storage.blob.agent_os_container
    container_id       = module.storage.blob.agent_os_container_id
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

# Network handoff for AGC (paragon workspace). Always present so paragon can
# resolve network even when the AGC association subnet is disabled.
resource "azurerm_key_vault_secret" "runtime_network" {
  name         = "network"
  key_vault_id = azurerm_key_vault.paragon.id
  value = jsonencode({
    private_subnet_id   = module.network.private_subnet.id
    private_subnet_cidr = module.network.private_subnet.address_prefixes[0]
    agc_subnet_id       = var.agc_subnet_enabled ? module.network.agc_subnet.id : null
    agc_subnet_cidr     = var.agc_subnet_enabled ? module.network.agc_subnet.address_prefixes[0] : null
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

# Agent OS app/admin secret payloads, composed from the postgres, redis-managed, storage and
# kafka modules and stored in Key Vault. Service pods only ever receive the app payload.

locals {
  agent_os_db    = try(one(module.postgres).agent_os, null)
  agent_os_cache = try(one(module.redis_managed).redis["agent_os"], null)
  agent_os_kafka = one(module.kafka)

  agent_os_cache_scheme = try(local.agent_os_cache.ssl, false) ? "rediss" : "redis"

  agent_os_app_config = var.agent_os_enabled ? {
    CONTEXT_POSTGRES_HOST        = local.agent_os_db.host
    CONTEXT_POSTGRES_PORT        = tostring(local.agent_os_db.port)
    CONTEXT_POSTGRES_DATABASE    = local.agent_os_db.databases.context.database
    CONTEXT_POSTGRES_USERNAME    = local.agent_os_db.databases.context.user
    CONTEXT_POSTGRES_PASSWORD    = local.agent_os_db.databases.context.password
    CONTEXT_POSTGRES_SSL_ENABLED = "true"
    CONTEXT_POSTGRES_SSL_CA      = ""

    TOOLS_POSTGRES_HOST        = local.agent_os_db.host
    TOOLS_POSTGRES_PORT        = tostring(local.agent_os_db.port)
    TOOLS_POSTGRES_DATABASE    = local.agent_os_db.databases.tools.database
    TOOLS_POSTGRES_USERNAME    = local.agent_os_db.databases.tools.user
    TOOLS_POSTGRES_PASSWORD    = local.agent_os_db.databases.tools.password
    TOOLS_POSTGRES_SSL_ENABLED = "true"
    TOOLS_POSTGRES_SSL_CA      = ""

    REDIS_HOST            = local.agent_os_cache.host
    REDIS_PORT            = tostring(local.agent_os_cache.port)
    REDIS_URL             = "${local.agent_os_cache_scheme}://:${urlencode(local.agent_os_cache.password)}@${local.agent_os_cache.host}:${local.agent_os_cache.port}"
    REDIS_PASSWORD        = local.agent_os_cache.password
    REDIS_TLS_ENABLED     = tostring(local.agent_os_cache.ssl)
    REDIS_CLUSTER_ENABLED = tostring(local.agent_os_cache.cluster)

    KAFKA_BROKER_URLS    = local.agent_os_kafka.bootstrap_servers
    KAFKA_SASL_USERNAME  = local.agent_os_kafka.agent_os_kafka_credentials.username
    KAFKA_SASL_PASSWORD  = local.agent_os_kafka.agent_os_kafka_credentials.password
    KAFKA_SASL_MECHANISM = local.agent_os_kafka.agent_os_kafka_credentials.mechanism
    KAFKA_SSL_ENABLED    = tostring(local.agent_os_kafka.tls_enabled)

    # Blob container, addressed through the S3_* keys the Agent OS config slices expect.
    AZURE_STORAGE_ACCOUNT = module.storage.blob.name
    S3_BUCKET             = module.storage.blob.agent_os_container
    S3_PARSED_BUCKET      = module.storage.blob.agent_os_container
    S3_PARSED_PREFIX      = "parsed/"
    S3_INDEX_BUCKET       = module.storage.blob.agent_os_container
    S3_INDEX_AZ_ID        = ""
  } : null

  agent_os_admin_config = var.agent_os_enabled ? {
    ADMIN_POSTGRES_HOST        = local.agent_os_db.host
    ADMIN_POSTGRES_PORT        = tostring(local.agent_os_db.port)
    ADMIN_POSTGRES_DATABASE    = local.agent_os_db.admin_database
    ADMIN_POSTGRES_USERNAME    = local.agent_os_db.admin_user
    ADMIN_POSTGRES_PASSWORD    = local.agent_os_db.admin_password
    ADMIN_POSTGRES_SSL_ENABLED = "true"
    ADMIN_POSTGRES_SSL_CA      = ""
  } : null
}
