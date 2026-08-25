output "postgres" {
  value = merge(
    {
      for name, config in local.postgres_instances :
      name => {
        host            = google_sql_database_instance.paragon[name].ip_address.0.ip_address
        port            = "5432"
        user            = random_string.postgres_root_username[name].result
        password        = random_password.postgres_root_password[name].result
        database        = google_sql_database.paragon[name].name
        max_storage_gib = var.postgres_disk_autoresize_limit
      }
    },
    local.openfga_instance_key != null ? {
      openfga = {
        host            = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port            = "5432"
        user            = random_string.openfga_username[0].result
        password        = random_password.openfga_password[0].result
        database        = "openfga"
        max_storage_gib = var.postgres_disk_autoresize_limit
      }
      sync_project = {
        host            = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port            = "5432"
        user            = random_string.managed_sync_db_username["sync_project"].result
        password        = random_password.managed_sync_db_password["sync_project"].result
        database        = "sync_project"
        max_storage_gib = var.postgres_disk_autoresize_limit
      }
      sync_instance = {
        host            = google_sql_database_instance.paragon[local.openfga_instance_key].ip_address.0.ip_address
        port            = "5432"
        user            = random_string.managed_sync_db_username["sync_instance"].result
        password        = random_password.managed_sync_db_password["sync_instance"].result
        database        = "sync_instance"
        max_storage_gib = var.postgres_disk_autoresize_limit
      }
    } : {}
  )
  sensitive = true
}
