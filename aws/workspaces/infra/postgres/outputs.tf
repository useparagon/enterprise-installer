# Agent OS: admin credentials for the migration Job plus one app user per logical database.
output "agent_os" {
  value = var.agent_os_enabled && contains(keys(local.agent_os_postgres_instances), "agent_os") ? {
    host           = aws_db_instance.agent_os["agent_os"].address
    port           = aws_db_instance.agent_os["agent_os"].port
    admin_database = aws_db_instance.agent_os["agent_os"].db_name
    admin_user     = aws_db_instance.agent_os["agent_os"].username
    admin_password = random_password.agent_os_root_password["agent_os"].result
    databases = {
      for name in local.agent_os_databases :
      name => {
        database = name
        user     = random_string.agent_os_app_username[name].result
        password = random_password.agent_os_app_password[name].result
      }
    }
  } : null
  sensitive = true
}

output "rds" {
  value = {
    for key, value in local.postgres_instances :
    key => {
      host     = aws_db_instance.postgres[key].address
      port     = aws_db_instance.postgres[key].port
      user     = aws_db_instance.postgres[key].username
      password = var.rds_restore_from_snapshot ? null : try(var.migrated_passwords[key], random_password.postgres_root_password[key].result)
      database = aws_db_instance.postgres[key].db_name
    }
  }
  sensitive = true
}
