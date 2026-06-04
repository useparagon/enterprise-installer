# Optional storage account for on-demand RDB export (portal/CLI). Export is not a Terraform
# resource; this account is the target for az redisenterprise database export operations.

resource "random_string" "export_storage_hash" {
  count = var.export_storage_enabled ? 1 : 0

  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "export" {
  count = var.export_storage_enabled ? 1 : 0

  name                = "${substr(replace(var.workspace, "/[^a-z0-9]/", ""), 0, 16)}${random_string.export_storage_hash[0].result}"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  account_tier             = "Standard"
  account_replication_type = var.export_storage_replication_type
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  public_network_access_enabled    = true
  shared_access_key_enabled        = true

  tags = merge(var.tags, { Name = "${var.workspace}-redis-managed-export" })
}

resource "azurerm_storage_container" "export" {
  count = var.export_storage_enabled ? 1 : 0

  name                  = var.export_storage_container_name
  storage_account_id    = azurerm_storage_account.export[0].id
  container_access_type = "private"
}

resource "azurerm_storage_account_network_rules" "export" {
  count = var.export_storage_enabled ? 1 : 0

  storage_account_id         = azurerm_storage_account.export[0].id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  virtual_network_subnet_ids = [var.private_subnet.id]
}

resource "azurerm_role_assignment" "export_storage" {
  for_each = var.export_storage_enabled ? local.redis_instances : {}

  scope                = azurerm_storage_account.export[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_managed_redis.redis[each.key].identity[0].principal_id
}
