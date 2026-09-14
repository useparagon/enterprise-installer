resource "random_string" "postgres_root_username" {
  for_each = local.postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  for_each = local.postgres_instances

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  for_each = local.postgres_instances

  name                = each.value.name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  administrator_login    = random_string.postgres_root_username[each.key].result
  administrator_password = random_password.postgres_root_password[each.key].result

  sku_name                      = each.value.sku
  version                       = coalesce(each.value.version, var.postgres_version)
  storage_mb                    = each.value.storage_mb
  auto_grow_enabled             = true
  backup_retention_days         = 7
  delegated_subnet_id           = var.private_subnet.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  tags                          = merge(var.tags, { Name = each.value.name })

  # Maintenance window: Monday at 14:00 UTC (same as AKS had before)
  # Note: PostgreSQL only supports weekly schedule, not monthly like AKS
  maintenance_window {
    day_of_week  = 1  # Monday (0=Sunday, 1=Monday, ..., 6=Saturday)
    start_hour   = 14 # 14:00 UTC
    start_minute = 0
  }

  dynamic "high_availability" {
    for_each = each.value.ha ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  lifecycle {
    ignore_changes = [
      high_availability[0].standby_availability_zone,
      # Azure can increase storage automatically, but cannot shrink it. Keep later
      # applies from attempting to restore the configured initial size.
      storage_mb,
      zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  for_each = local.postgres_instances

  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.postgres[each.key].id
  value     = "dblink,pg_cron,uuid-ossp"
}

resource "azurerm_postgresql_flexible_server_database" "paragon" {
  for_each = local.postgres_instances

  name      = each.value.db
  server_id = azurerm_postgresql_flexible_server.postgres[each.key].id
  collation = "en_US.utf8"
  charset   = "UTF8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.extensions]
}

resource "azurerm_management_lock" "postgres" {
  for_each = var.postgres_management_lock_enabled ? local.postgres_instances : {}

  name       = "${each.value.name}-can-not-delete"
  scope      = azurerm_postgresql_flexible_server.postgres[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Protect Postgres Flexible Server from accidental deletion."
}

# Agent OS runs on the `agent_os` Flexible Server from the instance map, with the `context` and
# `tools` logical databases side by side. App roles and grants are applied by the migration Job.

locals {
  agent_os_databases = contains(keys(local.postgres_instances), "agent_os") ? toset(["context", "tools"]) : toset([])
}

resource "azurerm_postgresql_flexible_server_database" "agent_os_logical" {
  for_each = local.agent_os_databases

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.postgres["agent_os"].id
  collation = "en_US.utf8"
  charset   = "UTF8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.extensions]
}

resource "random_string" "agent_os_app_username" {
  for_each = local.agent_os_databases

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "agent_os_app_password" {
  for_each = local.agent_os_databases

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}
