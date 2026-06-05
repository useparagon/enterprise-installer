locals {
  runtime_secret_names = {
    env          = "paragon/${local.workspace}/env"
    docker_cfg   = "paragon/${local.workspace}/docker-cfg"
    managed_sync = "paragon/${local.workspace}/managed-sync"
    openobserve  = "paragon/${local.workspace}/openobserve"
  }
}

resource "aws_secretsmanager_secret" "env" {
  name                    = local.runtime_secret_names.env
  description             = "Paragon application secrets for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "env" {
  secret_id     = aws_secretsmanager_secret.env.id
  secret_string = jsonencode(local.helm_secret_values)
}

resource "aws_secretsmanager_secret" "docker_cfg" {
  name                    = local.runtime_secret_names.docker_cfg
  description             = "Docker registry credentials for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "docker_cfg" {
  secret_id = aws_secretsmanager_secret.docker_cfg.id
  secret_string = jsonencode({
    dockerconfigjson = jsonencode({
      auths = {
        (var.docker_registry_server) = {
          username = var.docker_username
          password = var.docker_password
          email    = var.docker_email
          auth     = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  })
}

resource "aws_secretsmanager_secret" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name                    = local.runtime_secret_names.managed_sync
  description             = "Managed Sync secrets for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  secret_id     = aws_secretsmanager_secret.managed_sync[0].id
  secret_string = jsonencode(module.managed_sync_config[0].config)
}

resource "aws_secretsmanager_secret" "openobserve" {
  count = 1

  name                    = local.runtime_secret_names.openobserve
  description             = "OpenObserve credentials for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "openobserve" {
  count = 1

  secret_id = aws_secretsmanager_secret.openobserve[0].id
  secret_string = jsonencode({
    ZO_ROOT_USER_EMAIL    = local.openobserve_email
    ZO_ROOT_USER_PASSWORD = local.openobserve_password
  })
}

# Gate Helm/ESO until Secrets Manager values exist (not just secret metadata).
resource "terraform_data" "runtime_secrets_populated" {
  input = {
    env          = aws_secretsmanager_secret_version.env.version_id
    docker_cfg   = aws_secretsmanager_secret_version.docker_cfg.version_id
    openobserve  = aws_secretsmanager_secret_version.openobserve[0].version_id
    managed_sync = var.managed_sync_enabled ? aws_secretsmanager_secret_version.managed_sync[0].version_id : null
  }
}
