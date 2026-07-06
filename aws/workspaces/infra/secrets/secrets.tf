locals {
  secret_prefix = "paragon/${var.workspace}"
}

resource "random_string" "openobserve_email" {
  count = var.create_openobserve ? 1 : 0

  length  = 12
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "random_password" "openobserve_password" {
  count = var.create_openobserve ? 1 : 0

  length  = 32
  lower   = true
  numeric = true
  special = false
  upper   = true
}

resource "aws_secretsmanager_secret" "env" {
  name                    = "${local.secret_prefix}/env"
  description             = "Paragon application environment variables for ${var.organization}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name         = "${local.secret_prefix}/env"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "env" {
  secret_id     = aws_secretsmanager_secret.env.id
  secret_string = jsonencode(var.env_config)
}

resource "aws_secretsmanager_secret" "docker_cfg" {
  count = var.docker_config != null ? 1 : 0

  name                    = "${local.secret_prefix}/docker-cfg"
  description             = "Docker registry credentials for ${var.organization}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name         = "${local.secret_prefix}/docker-cfg"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "docker_cfg" {
  count = var.docker_config != null ? 1 : 0

  secret_id     = aws_secretsmanager_secret.docker_cfg[0].id
  secret_string = var.docker_config
}

resource "aws_secretsmanager_secret" "managed_sync" {
  count = var.managed_sync_config != null ? 1 : 0

  name                    = "${local.secret_prefix}/managed-sync"
  description             = "Managed sync secrets for ${var.organization}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name         = "${local.secret_prefix}/managed-sync"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "managed_sync" {
  count = var.managed_sync_config != null ? 1 : 0

  secret_id     = aws_secretsmanager_secret.managed_sync[0].id
  secret_string = jsonencode(var.managed_sync_config)
}

resource "aws_secretsmanager_secret" "openobserve" {
  count = var.create_openobserve ? 1 : 0

  name                    = "${local.secret_prefix}/openobserve"
  description             = "OpenObserve credentials for ${var.organization}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name         = "${local.secret_prefix}/openobserve"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "openobserve" {
  count = var.create_openobserve ? 1 : 0

  secret_id = aws_secretsmanager_secret.openobserve[0].id
  secret_string = jsonencode({
    ZO_ROOT_USER_EMAIL    = "${random_string.openobserve_email[0].result}@useparagon.com"
    ZO_ROOT_USER_PASSWORD = random_password.openobserve_password[0].result
  })
}
