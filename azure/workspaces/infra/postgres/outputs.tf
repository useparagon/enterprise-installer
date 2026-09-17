# Agent OS: admin credentials for the migration Job plus one app user per logical database.
output "agent_os" {
  value = contains(keys(local.postgres_instances), "agent_os") ? {
    host           = azurerm_postgresql_flexible_server.postgres["agent_os"].fqdn
    port           = var.postgres_port
    admin_database = azurerm_postgresql_flexible_server_database.paragon["agent_os"].name
    admin_user     = random_string.postgres_root_username["agent_os"].result
    admin_password = random_password.postgres_root_password["agent_os"].result
    databases = {
      for name in local.agent_os_databases :
      name => {
        database = azurerm_postgresql_flexible_server_database.agent_os_logical[name].name
        user     = random_string.agent_os_app_username[name].result
        password = random_password.agent_os_app_password[name].result
      }
    }
  } : null
  sensitive = true
}

output "postgres" {
  value = {
    for key, value in local.postgres_instances :
    key => {
      host     = azurerm_postgresql_flexible_server.postgres[key].fqdn
      port     = var.postgres_port
      user     = random_string.postgres_root_username[key].result
      password = random_password.postgres_root_password[key].result
      database = azurerm_postgresql_flexible_server_database.paragon[key].name
    }
    if key != "agent_os"
  }
  sensitive = true
}
