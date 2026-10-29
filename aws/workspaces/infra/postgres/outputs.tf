output "agent_os" {
  value = var.agent_os_enabled && contains(keys(var.postgres_instances), "agent_os") ? {
    host           = aws_db_instance.postgres["agent_os"].address
    port           = aws_db_instance.postgres["agent_os"].port
    admin_database = aws_db_instance.postgres["agent_os"].db_name
    admin_user     = aws_db_instance.postgres["agent_os"].username
    admin_password = random_password.postgres_root_password["agent_os"].result
    databases = {
      for name in local.agent_os_databases :
      name => {
        database = name
        user     = random_string.agent_os_app_username[name].result
        password = random_password.agent_os_app_password[name].result
      }
    }
    capability_broker = {
      user     = random_string.agent_os_capability_broker_username[0].result
      password = random_password.agent_os_capability_broker_password[0].result
    }
  } : null
  sensitive = true
}

output "rds" {
  value = {
    for key, cfg in var.postgres_instances :
    key => {
      host         = aws_db_instance.postgres[key].address
      port         = aws_db_instance.postgres[key].port
      user         = aws_db_instance.postgres[key].username
      password     = var.rds_restore_from_snapshot ? null : try(var.migrated_passwords[key], random_password.postgres_root_password[key].result)
      database     = aws_db_instance.postgres[key].db_name
      replica_host = try(aws_db_instance.postgres_replica[key].address, null)
    }
  }
  sensitive = true
}

output "pg_config" {
  description = "Non-sensitive RDS storage alerts keyed by logical instance name."
  value = {
    for key, cfg in var.postgres_instances :
    key => {
      max_storage_bytes = cfg.max_allocated_storage * 1073741824
    }
  }
}
