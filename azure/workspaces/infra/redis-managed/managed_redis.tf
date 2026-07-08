resource "azurerm_managed_redis" "redis" {
  for_each = local.redis_instances

  name                = "${var.workspace}-${each.key}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  sku_name            = each.value.sku

  high_availability_enabled = each.value.high_availability_enabled
  public_network_access     = var.public_network_access

  tags = merge(var.tags, { Name = "${var.workspace}-${each.key}" })

  dynamic "identity" {
    for_each = var.export_storage_enabled ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  default_database {
    access_keys_authentication_enabled = true
    client_protocol                    = "Encrypted"
    clustering_policy                  = each.value.clustering_policy
    eviction_policy                    = "VolatileLRU"

    persistence_redis_database_backup_frequency   = each.value.rdb_backup_frequency
    persistence_append_only_file_backup_frequency = each.value.aof_backup_frequency
  }

  # Azure Managed Redis (Redis Enterprise) provisioning can be slow and occasionally
  # completes server-side after the client gives up, leaving an orphaned cluster
  # and broken state. Allow ample time so the apply waits for completion.
  timeouts {
    create = "90m"
    update = "90m"
    delete = "60m"
  }
}
