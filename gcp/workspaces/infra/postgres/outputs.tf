# Agent OS: admin credentials for the migration Job plus one app user per logical database.
output "agent_os" {
  value = var.agent_os_enabled && contains(keys(local.agent_os_postgres_instances), "agent_os") ? {
    host           = google_sql_database_instance.agent_os["agent_os"].private_ip_address
    port           = "5432"
    admin_database = "postgres"
    admin_user     = google_sql_user.agent_os_root["agent_os"].name
    admin_password = random_password.agent_os_root_password["agent_os"].result
    databases = {
      for name in local.agent_os_databases :
      name => {
        database = google_sql_database.agent_os[name].name
        user     = google_sql_user.agent_os_app[name].name
        password = random_password.agent_os_app_password[name].result
      }
    }
  } : null
  sensitive = true
}

output "postgres" {
  value = merge(
    {
      for name, config in local.postgres_instances :
      name => {
        host     = google_sql_database_instance.paragon[name].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.postgres_root_username[name].result
        password = random_password.postgres_root_password[name].result
        database = google_sql_database.paragon[name].name
      }
    },
    local.openfga_instance_key != null ? {
      openfga = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.openfga_username[0].result
        password = random_password.openfga_password[0].result
        database = "openfga"
      }
      sync_project = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.managed_sync_db_username["sync_project"].result
        password = random_password.managed_sync_db_password["sync_project"].result
        database = "sync_project"
      }
      sync_instance = {
        host     = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port     = "5432"
        user     = random_string.managed_sync_db_username["sync_instance"].result
        password = random_password.managed_sync_db_password["sync_instance"].result
        database = "sync_instance"
      }
    } : {}
  )
  sensitive = true
}
