locals {
  runtime_secret_names = {
    env          = "paragon/${local.workspace}/env"
    docker_cfg   = "paragon/${local.workspace}/docker-cfg"
    managed_sync = "paragon/${local.workspace}/managed-sync"
    openobserve  = "paragon/${local.workspace}/openobserve"
  }
}

resource "aws_secretsmanager_secret" "env" {
  count = var.argocd_enabled ? 0 : 1

  name                    = local.runtime_secret_names.env
  description             = "Paragon application secrets for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "env" {
  count = var.argocd_enabled ? 0 : 1

  secret_id     = aws_secretsmanager_secret.env[0].id
  secret_string = jsonencode(local.helm_secret_values)
}

data "aws_secretsmanager_secret" "env" {
  count = var.argocd_enabled ? 1 : 0
  name  = local.runtime_secret_names.env
}

resource "aws_secretsmanager_secret" "docker_cfg" {
  count = var.argocd_enabled ? 0 : 1

  name                    = local.runtime_secret_names.docker_cfg
  description             = "Docker registry credentials for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "docker_cfg" {
  count = var.argocd_enabled ? 0 : 1

  secret_id = aws_secretsmanager_secret.docker_cfg[0].id
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

data "aws_secretsmanager_secret" "docker_cfg" {
  count = var.argocd_enabled ? 1 : 0
  name  = local.runtime_secret_names.docker_cfg
}

resource "aws_secretsmanager_secret" "managed_sync" {
  count = !var.argocd_enabled && var.managed_sync_enabled ? 1 : 0

  name                    = local.runtime_secret_names.managed_sync
  description             = "Managed Sync secrets for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "managed_sync" {
  count = !var.argocd_enabled && var.managed_sync_enabled ? 1 : 0

  secret_id     = aws_secretsmanager_secret.managed_sync[0].id
  secret_string = jsonencode(module.managed_sync_config[0].config)
}

data "aws_secretsmanager_secret" "managed_sync" {
  count = var.argocd_enabled && var.managed_sync_enabled ? 1 : 0
  name  = local.runtime_secret_names.managed_sync
}

resource "aws_secretsmanager_secret" "openobserve" {
  count = var.argocd_enabled ? 0 : 1

  name                    = local.runtime_secret_names.openobserve
  description             = "OpenObserve credentials for ${var.organization}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "openobserve" {
  count = var.argocd_enabled ? 0 : 1

  secret_id = aws_secretsmanager_secret.openobserve[0].id
  secret_string = jsonencode({
    ZO_ROOT_USER_EMAIL    = local.openobserve_email
    ZO_ROOT_USER_PASSWORD = local.openobserve_password
  })
}

data "aws_secretsmanager_secret" "openobserve" {
  count = var.argocd_enabled ? 1 : 0
  name  = local.runtime_secret_names.openobserve
}

data "aws_secretsmanager_secret_version" "env" {
  count     = var.argocd_enabled ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.env[0].id
}

data "aws_secretsmanager_secret_version" "docker_cfg" {
  count     = var.argocd_enabled ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.docker_cfg[0].id
}

data "aws_secretsmanager_secret_version" "managed_sync" {
  count     = var.argocd_enabled && var.managed_sync_enabled ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.managed_sync[0].id
}

data "aws_secretsmanager_secret_version" "openobserve" {
  count     = var.argocd_enabled ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.openobserve[0].id
}

locals {
  runtime_env_secret_name          = var.argocd_enabled ? data.aws_secretsmanager_secret.env[0].name : aws_secretsmanager_secret.env[0].name
  runtime_docker_cfg_secret_name   = var.argocd_enabled ? data.aws_secretsmanager_secret.docker_cfg[0].name : aws_secretsmanager_secret.docker_cfg[0].name
  runtime_openobserve_secret_name  = var.argocd_enabled ? data.aws_secretsmanager_secret.openobserve[0].name : aws_secretsmanager_secret.openobserve[0].name
  runtime_managed_sync_secret_name = var.managed_sync_enabled ? (var.argocd_enabled ? data.aws_secretsmanager_secret.managed_sync[0].name : aws_secretsmanager_secret.managed_sync[0].name) : null
}

# Gate Helm/ESO until Secrets Manager values exist (not just secret metadata).
resource "terraform_data" "runtime_secrets_populated" {
  input = var.argocd_enabled ? {
    env          = data.aws_secretsmanager_secret_version.env[0].version_id
    docker_cfg   = data.aws_secretsmanager_secret_version.docker_cfg[0].version_id
    openobserve  = data.aws_secretsmanager_secret_version.openobserve[0].version_id
    managed_sync = var.managed_sync_enabled ? data.aws_secretsmanager_secret_version.managed_sync[0].version_id : null
    } : {
    env          = aws_secretsmanager_secret_version.env[0].version_id
    docker_cfg   = aws_secretsmanager_secret_version.docker_cfg[0].version_id
    openobserve  = aws_secretsmanager_secret_version.openobserve[0].version_id
    managed_sync = var.managed_sync_enabled ? aws_secretsmanager_secret_version.managed_sync[0].version_id : null
  }
}
