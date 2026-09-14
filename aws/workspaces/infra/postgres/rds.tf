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

# Agent OS Postgres. Dedicated instance so the Paragon/Managed Sync instance map above
# keeps its resource addresses; hosts the `context` and `tools` logical databases.

locals {
  agent_os_postgres_config_defaults = {
    instance_class         = "db.t4g.medium"
    allocated_storage      = 100
    max_allocated_storage  = 1000
    engine_version         = "16.13"
    multi_az               = true
    read_replica           = false
    replica_instance_class = "db.t4g.small"
    storage_type           = "gp3"
  }

  # Partial overrides set omitted attributes to null; drop them so defaults survive the merge.
  agent_os_postgres_config = merge(
    local.agent_os_postgres_config_defaults,
    { for key, value in try(var.agent_os_postgres["agent_os"], {}) : key => value if value != null },
  )

  agent_os_postgres_name   = "${var.workspace}-agent-os"
  agent_os_postgres_family = "postgres${split(".", local.agent_os_postgres_config.engine_version)[0]}"

  # gp3 below 400 GiB uses fixed AWS baselines that cannot be specified (see rds.tf).
  agent_os_gp3_striped = local.agent_os_postgres_config.storage_type == "gp3" && local.agent_os_postgres_config.allocated_storage >= 400

  # One physical instance, one app user per logical database. The databases and grants are
  # applied by the Agent OS migration Job using the admin credentials.
  agent_os_databases = var.agent_os_enabled ? toset(["context", "tools"]) : toset([])
}

check "agent_os_postgres_storage" {
  assert {
    condition = (
      local.agent_os_postgres_config.max_allocated_storage >= 100 &&
      local.agent_os_postgres_config.max_allocated_storage >= ceil(local.agent_os_postgres_config.allocated_storage * 1.1)
    )
    error_message = "Agent OS Postgres max_allocated_storage must be at least 100 GiB and at least 10% greater than allocated_storage."
  }

  assert {
    condition     = contains(["gp2", "gp3"], local.agent_os_postgres_config.storage_type)
    error_message = "Agent OS Postgres storage_type must be gp2 or gp3."
  }
}

resource "random_string" "agent_os_root_username" {
  count = var.agent_os_enabled ? 1 : 0

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "agent_os_root_password" {
  count = var.agent_os_enabled ? 1 : 0

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
  count = var.agent_os_enabled ? 1 : 0

  name        = "${local.agent_os_postgres_name}-subnet"
  description = "Agent OS Postgres subnet group"
  subnet_ids  = var.private_subnet[*].id

  tags = {
    Name = "${local.agent_os_postgres_name}-subnet"
  }
}

resource "aws_db_parameter_group" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name   = "${local.agent_os_postgres_name}-${local.agent_os_postgres_family}"
  family = local.agent_os_postgres_family

  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = 1000
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.agent_os_postgres_name}-postgres-group"
  }
}

resource "aws_db_instance" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  identifier = local.agent_os_postgres_name
  db_name    = "postgres"
  port       = "5432"
  username   = random_string.agent_os_root_username[0].result
  password   = random_password.agent_os_root_password[0].result

  engine               = "postgres"
  engine_version       = local.agent_os_postgres_config.engine_version
  instance_class       = local.agent_os_postgres_config.instance_class
  parameter_group_name = aws_db_parameter_group.agent_os[0].name
  storage_type         = local.agent_os_postgres_config.storage_type

  iops               = local.agent_os_gp3_striped ? 12000 : null
  storage_throughput = local.agent_os_gp3_striped ? 500 : null

  allocated_storage           = local.agent_os_postgres_config.allocated_storage
  max_allocated_storage       = local.agent_os_postgres_config.max_allocated_storage
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  availability_zone           = local.agent_os_postgres_config.multi_az ? null : var.availability_zones.names[0]
  backup_retention_period     = 7
  backup_window               = "06:00-07:00"
  ca_cert_identifier          = "rds-ca-rsa2048-g1"
  maintenance_window          = "Tue:04:00-Tue:05:00"
  monitoring_interval         = 15
  monitoring_role_arn         = aws_iam_role.rds_enhanced_monitoring.arn
  multi_az                    = local.agent_os_postgres_config.multi_az

  db_subnet_group_name      = aws_db_subnet_group.agent_os[0].id
  deletion_protection       = !var.disable_deletion_protection
  skip_final_snapshot       = !var.rds_final_snapshot_enabled
  final_snapshot_identifier = var.rds_final_snapshot_enabled ? "${local.agent_os_postgres_name}-${random_string.snapshot_identifier[0].result}" : null
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
    Name = local.agent_os_postgres_name
  }
}

resource "aws_db_instance" "agent_os_replica" {
  count = var.agent_os_enabled && local.agent_os_postgres_config.read_replica ? 1 : 0

  identifier          = "${local.agent_os_postgres_name}-replica"
  replicate_source_db = aws_db_instance.agent_os[0].arn
  instance_class      = local.agent_os_postgres_config.replica_instance_class

  engine               = "postgres"
  engine_version       = local.agent_os_postgres_config.engine_version
  parameter_group_name = aws_db_parameter_group.agent_os[0].name
  storage_type         = local.agent_os_postgres_config.storage_type

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

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.agent_os_kms_key_arn
  performance_insights_retention_period = 31
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  apply_immediately = true

  tags = {
    Name = "${local.agent_os_postgres_name}-replica"
  }
}
