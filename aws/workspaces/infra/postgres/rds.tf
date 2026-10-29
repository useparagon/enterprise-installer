locals {
  postgres_family = "postgres${split(".", var.rds_postgres_version)[0]}" // e.g. `postgres11`, `postgres12`, etc

  postgres_gp3_striped = {
    for key, cfg in var.postgres_instances :
    key => cfg.storage_type == "gp3" && cfg.allocated_storage >= 400
  }
  postgres_gp3_custom = {
    for key, cfg in var.postgres_instances :
    key => cfg.iops != null && cfg.storage_throughput != null
  }
  postgres_gp3_iops_effective = {
    for key, cfg in var.postgres_instances :
    key => local.postgres_gp3_striped[key] ? (local.postgres_gp3_custom[key] ? cfg.iops : 12000) : null
  }
  postgres_gp3_storage_throughput_effective = {
    for key, cfg in var.postgres_instances :
    key => local.postgres_gp3_striped[key] ? (local.postgres_gp3_custom[key] ? cfg.storage_throughput : 500) : null
  }

  agent_os_databases = var.agent_os_enabled && contains(keys(var.postgres_instances), "agent_os") ? toset(["context", "tools"]) : toset([])
}

resource "random_string" "postgres_root_username" {
  for_each = var.postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  for_each = {
    for key, value in var.postgres_instances :
    key => value
    if try(var.migrated_passwords[key], null) == null
  }

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "random_string" "snapshot_identifier" {
  count = var.rds_final_snapshot_enabled ? 1 : 0

  length  = 8
  numeric = false
  special = false
  lower   = true
  upper   = false
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

resource "random_string" "agent_os_capability_broker_username" {
  count = var.agent_os_enabled ? 1 : 0

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "agent_os_capability_broker_password" {
  count = var.agent_os_enabled ? 1 : 0

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "aws_db_subnet_group" "postgres" {
  name        = "${var.workspace}-postgres-subnet"
  description = "${var.workspace} postgres subnet group"
  subnet_ids  = var.private_subnet[*].id

  tags = {
    Name = "${var.workspace}-postgres-subnet"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${var.workspace}-${local.postgres_family}"
  family = local.postgres_family

  dynamic "parameter" {
    for_each = [
      {
        name         = "log_statement"
        value        = "ddl"
        apply_method = "pending-reboot"
      },
      {
        name         = "log_min_duration_statement"
        value        = 1000
        apply_method = "pending-reboot"
      },
      {
        name         = "max_connections"
        value        = 10000
        apply_method = "pending-reboot"
      },
      {
        name         = "wal_buffers"
        value        = "2048" # sets `wal_buffers` to 16mb
        apply_method = "pending-reboot"
      },
    ]
    content {
      apply_method = lookup(parameter.value, "apply_method", null)
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-postgres-group"
  }
}

data "aws_db_snapshot" "postgres" {
  for_each = var.rds_restore_from_snapshot ? var.postgres_instances : {}

  db_instance_identifier = each.value.identifier
  most_recent            = true
}

resource "aws_db_instance" "postgres" {
  for_each = var.postgres_instances

  identifier = each.value.identifier
  db_name    = each.value.database_name
  port       = tostring(each.value.port)
  username   = var.rds_restore_from_snapshot ? null : random_string.postgres_root_username[each.key].result
  password   = var.rds_restore_from_snapshot ? null : try(var.migrated_passwords[each.key], random_password.postgres_root_password[each.key].result)

  engine               = "postgres"
  engine_version       = each.value.engine_version
  instance_class       = each.value.instance_class
  parameter_group_name = aws_db_parameter_group.postgres.name
  storage_type         = each.value.storage_type

  iops               = local.postgres_gp3_iops_effective[each.key]
  storage_throughput = local.postgres_gp3_storage_throughput_effective[each.key]

  allocated_storage     = each.value.allocated_storage
  max_allocated_storage = each.value.max_allocated_storage

  allow_major_version_upgrade = each.value.allow_major_version_upgrade
  auto_minor_version_upgrade  = each.value.auto_minor_version_upgrade
  availability_zone           = each.value.availability_zone
  backup_retention_period     = each.value.backup_retention_days
  backup_window               = each.value.backup_window
  ca_cert_identifier          = each.value.ca_cert_identifier
  maintenance_window          = each.value.maintenance_window
  monitoring_interval         = each.value.monitoring_interval
  monitoring_role_arn         = aws_iam_role.rds_enhanced_monitoring.arn
  multi_az                    = each.value.multi_az

  db_subnet_group_name      = aws_db_subnet_group.postgres.id
  deletion_protection       = each.value.deletion_protection
  snapshot_identifier       = var.rds_restore_from_snapshot ? data.aws_db_snapshot.postgres[each.key].id : null
  skip_final_snapshot       = !var.rds_final_snapshot_enabled
  final_snapshot_identifier = var.rds_final_snapshot_enabled ? "${each.value.identifier}-${random_string.snapshot_identifier[0].result}" : null
  publicly_accessible       = false
  storage_encrypted         = true
  kms_key_id                = each.value.kms_key_arn
  vpc_security_group_ids    = [aws_security_group.postgres.id]

  performance_insights_enabled          = each.value.performance_insights_enabled
  performance_insights_kms_key_id       = each.value.kms_key_arn != null && each.value.performance_insights_enabled ? each.value.kms_key_arn : null
  performance_insights_retention_period = each.value.performance_insights_enabled ? each.value.performance_insights_retention_days : null
  enabled_cloudwatch_logs_exports       = each.value.enabled_cloudwatch_logs_exports

  apply_immediately = each.value.apply_immediately

  tags = merge({ Name = each.value.identifier }, each.value.tags)
}

resource "aws_db_instance" "postgres_replica" {
  for_each = {
    for key, cfg in var.postgres_instances : key => cfg
    if cfg.read_replica
  }

  identifier          = "${each.value.identifier}-replica"
  replicate_source_db = aws_db_instance.postgres[each.key].identifier
  instance_class      = each.value.replica_instance_class

  parameter_group_name = aws_db_parameter_group.postgres.name

  auto_minor_version_upgrade = each.value.auto_minor_version_upgrade
  ca_cert_identifier         = each.value.ca_cert_identifier
  maintenance_window         = each.value.maintenance_window
  monitoring_interval        = each.value.monitoring_interval
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn

  deletion_protection    = each.value.deletion_protection
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_encrypted      = true
  vpc_security_group_ids = [aws_security_group.postgres.id]

  enabled_cloudwatch_logs_exports = each.value.enabled_cloudwatch_logs_exports

  apply_immediately = each.value.apply_immediately

  tags = merge({ Name = "${each.value.identifier}-replica" }, each.value.tags)
}
