output "redis" {
  description = "Connection information for each Azure Managed Redis instance (Redis 7.4)."
  # Iterate managed_redis resources, not local.redis_instances, so mid-apply output
  # evaluation does not index keys whose instances are not created yet.
  value = {
    for key, redis in azurerm_managed_redis.redis :
    key => {
      host     = redis.hostname
      port     = redis.default_database[0].port
      password = redis.default_database[0].primary_access_key
      ssl      = true
      cluster  = local.redis_instances[key].cluster
      connection_string = format(
        ":%s@%s:%s",
        urlencode(redis.default_database[0].primary_access_key),
        redis.hostname,
        redis.default_database[0].port,
      )
    }
  }
  sensitive = true
}

output "export_storage" {
  description = "Optional blob storage for on-demand RDB export (null when export_storage_enabled is false)."
  value = var.export_storage_enabled ? {
    storage_account_name = azurerm_storage_account.export[0].name
    container_name       = azurerm_storage_container.export[0].name
    resource_group_name  = var.resource_group.name
  } : null
}
