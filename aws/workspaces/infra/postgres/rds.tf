locals {
  postgres_family = "postgres${split(".", var.rds_postgres_version)[0]}" // e.g. `postgres11`, `postgres12`, etc

  # gp3 PostgreSQL stripes at >= 400 GiB (12k IOPS / 500 MiB/s baseline). Below 400 GiB gp3 uses a
  # fixed 3000 IOPS / 125 MiB/s that AWS does NOT allow you to specify; passing iops/storage_throughput
  # for those sizes fails with InvalidParameterCombination, so they must be omitted (null).
  # Custom values must be set as a valid pair and are only honored at >= 400 GiB (enforced by variable validation).
  rds_gp3_striped                      = var.rds_allocated_storage >= 400
  rds_gp3_custom                       = var.rds_gp3_iops != null && var.rds_gp3_storage_throughput != null
  rds_gp3_iops_effective               = local.rds_gp3_striped ? (local.rds_gp3_custom ? var.rds_gp3_iops : 12000) : null
  rds_gp3_storage_throughput_effective = local.rds_gp3_striped ? (local.rds_gp3_custom ? var.rds_gp3_storage_throughput : 500) : null
}

resource "random_string" "postgres_root_username" {
  for_each = local.postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  for_each = {
    for key, value in local.postgres_instances :
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

resource "aws_db_subnet_group" "postgres" {
  name        = "${var.workspace}-postgres-subnet"
  description = "${var.workspace} postgres subnet group"
  subnet_ids  = var.private_subnet.*.id

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
  for_each = var.rds_restore_from_snapshot ? local.postgres_instances : {}

  db_instance_identifier = each.value.name
  most_recent            = true
}

resource "aws_db_instance" "postgres" {
  for_each = local.postgres_instances

  identifier = each.value.name
  db_name    = each.value.db
  port       = "5432"
  username   = var.rds_restore_from_snapshot ? null : random_string.postgres_root_username[each.key].result
  password   = var.rds_restore_from_snapshot ? null : try(var.migrated_passwords[each.key], random_password.postgres_root_password[each.key].result)

  engine               = "postgres"
  engine_version       = var.rds_postgres_version
  instance_class       = each.value.size
  parameter_group_name = aws_db_parameter_group.postgres.name
  storage_type         = "gp3"

  iops               = local.rds_gp3_iops_effective
  storage_throughput = local.rds_gp3_storage_throughput_effective

  allocated_storage           = var.rds_allocated_storage
  max_allocated_storage       = var.rds_max_allocated_storage
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  availability_zone           = var.rds_multi_az ? null : var.availability_zones.names[0]
  backup_retention_period     = 7
  backup_window               = "06:00-07:00"
  ca_cert_identifier          = "rds-ca-rsa2048-g1"
  maintenance_window          = "Tue:04:00-Tue:05:00"
  monitoring_interval         = 15
  monitoring_role_arn         = aws_iam_role.rds_enhanced_monitoring.arn
  multi_az                    = var.rds_multi_az

  db_subnet_group_name      = aws_db_subnet_group.postgres.id
  deletion_protection       = !var.disable_deletion_protection
  snapshot_identifier       = var.rds_restore_from_snapshot ? data.aws_db_snapshot.postgres[each.key].id : null
  skip_final_snapshot       = !var.rds_final_snapshot_enabled
  final_snapshot_identifier = var.rds_final_snapshot_enabled ? "${each.value.name}-${random_string.snapshot_identifier[0].result}" : null
  publicly_accessible       = false
  storage_encrypted         = true
  vpc_security_group_ids    = [aws_security_group.postgres.id]

  performance_insights_enabled          = true
  performance_insights_retention_period = 31
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  apply_immediately = true
}

# Agent OS Postgres instances are driven by the workspace-level map so each physical
# instance can be sized and changed independently without affecting Paragon/Managed Sync.
locals {
  agent_os_postgres_instances = var.agent_os_enabled ? var.agent_os_postgres : {}

  agent_os_postgres_names = {
    for key, _ in local.agent_os_postgres_instances :
    key => key == "agent_os" ? "${var.workspace}-agent-os" : "${var.workspace}-agent-os-${replace(key, "_", "-")}"
  }

  agent_os_postgres_families = {
    for key, cfg in local.agent_os_postgres_instances :
    key => "postgres${split(".", cfg.engine_version)[0]}"
  }

  # gp3 below 400 GiB uses fixed AWS baselines that cannot be specified. At or
  # above 400 GiB, callers may override the 12k IOPS / 500 MiB/s baseline per instance.
  agent_os_gp3_striped = {
    for key, cfg in local.agent_os_postgres_instances :
    key => cfg.storage_type == "gp3" && cfg.allocated_storage >= 400
  }
  agent_os_gp3_iops_effective = {
    for key, cfg in local.agent_os_postgres_instances :
    key => local.agent_os_gp3_striped[key] ? (cfg.iops != null ? cfg.iops : 12000) : null
  }
  agent_os_gp3_storage_throughput_effective = {
    for key, cfg in local.agent_os_postgres_instances :
    key => local.agent_os_gp3_striped[key] ? (cfg.storage_throughput != null ? cfg.storage_throughput : 500) : null
  }

  # `context` and `tools` are the logical Agent OS databases on the primary
  # `agent_os` physical instance. Additional map entries are independent servers.
  agent_os_databases = var.agent_os_enabled && contains(keys(local.agent_os_postgres_instances), "agent_os") ? toset(["context", "tools"]) : toset([])
}

resource "random_string" "agent_os_root_username" {
  for_each = local.agent_os_postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "agent_os_root_password" {
  for_each = local.agent_os_postgres_instances

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
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

resource "aws_db_subnet_group" "agent_os" {
  count = var.agent_os_enabled && length(local.agent_os_postgres_instances) > 0 ? 1 : 0

  name        = "${var.workspace}-agent-os-subnet"
  description = "Agent OS Postgres subnet group"
  subnet_ids  = var.private_subnet[*].id

  tags = {
    Name = "${var.workspace}-agent-os-subnet"
  }
}

resource "aws_db_parameter_group" "agent_os" {
  for_each = local.agent_os_postgres_instances

  name   = "${local.agent_os_postgres_names[each.key]}-${local.agent_os_postgres_families[each.key]}"
  family = local.agent_os_postgres_families[each.key]

  parameter {
    name         = "log_statement"
    value        = each.value.log_statement
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = each.value.log_min_duration_statement
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.agent_os_postgres_names[each.key]}-postgres-group"
  }
}

resource "aws_db_instance" "agent_os" {
  for_each = local.agent_os_postgres_instances

  identifier = local.agent_os_postgres_names[each.key]
  db_name    = "postgres"
  port       = "5432"
  username   = random_string.agent_os_root_username[each.key].result
  password   = random_password.agent_os_root_password[each.key].result

  engine               = "postgres"
  engine_version       = each.value.engine_version
  instance_class       = each.value.instance_class
  parameter_group_name = aws_db_parameter_group.agent_os[each.key].name
  storage_type         = each.value.storage_type

  iops               = local.agent_os_gp3_iops_effective[each.key]
  storage_throughput = local.agent_os_gp3_storage_throughput_effective[each.key]

  allocated_storage           = each.value.allocated_storage
  max_allocated_storage       = each.value.max_allocated_storage
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  availability_zone           = each.value.multi_az ? null : var.availability_zones.names[0]
  backup_retention_period     = each.value.backup_retention_days
  backup_window               = "06:00-07:00"
  ca_cert_identifier          = "rds-ca-rsa2048-g1"
  maintenance_window          = "Tue:04:00-Tue:05:00"
  monitoring_interval         = 15
  monitoring_role_arn         = aws_iam_role.rds_enhanced_monitoring.arn
  multi_az                    = each.value.multi_az

  db_subnet_group_name      = aws_db_subnet_group.agent_os[0].id
  deletion_protection       = !var.disable_deletion_protection
  skip_final_snapshot       = !var.rds_final_snapshot_enabled
  final_snapshot_identifier = var.rds_final_snapshot_enabled ? "${local.agent_os_postgres_names[each.key]}-${random_string.snapshot_identifier[0].result}" : null
  publicly_accessible       = false
  storage_encrypted         = true
  kms_key_id                = var.agent_os_kms_key_arn
  vpc_security_group_ids    = [aws_security_group.agent_os[0].id]

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.agent_os_kms_key_arn
  performance_insights_retention_period = 31
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  apply_immediately = true

  tags = {
    Name = local.agent_os_postgres_names[each.key]
  }
}

resource "aws_db_instance" "agent_os_replica" {
  for_each = {
    for key, cfg in local.agent_os_postgres_instances : key => cfg
    if cfg.read_replica
  }

  identifier          = "${local.agent_os_postgres_names[each.key]}-replica"
  replicate_source_db = aws_db_instance.agent_os[each.key].arn
  instance_class      = each.value.replica_instance_class

  engine               = "postgres"
  engine_version       = each.value.engine_version
  parameter_group_name = aws_db_parameter_group.agent_os[each.key].name
  storage_type         = each.value.storage_type

  auto_minor_version_upgrade = true
  ca_cert_identifier         = "rds-ca-rsa2048-g1"
  maintenance_window         = "Tue:04:00-Tue:05:00"
  monitoring_interval        = 15
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn

  deletion_protection    = !var.disable_deletion_protection
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_encrypted      = true
  vpc_security_group_ids = [aws_security_group.agent_os[0].id]

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  apply_immediately = true

  tags = {
    Name = "${local.agent_os_postgres_names[each.key]}-replica"
  }
}
