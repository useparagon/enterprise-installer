# Infra workspace owns base Secrets Manager secrets (PARA-21726). This workspace
# reads them and writes overlay versions for chart-specific keys only.

locals {
  runtime_secret_names = {
    env          = "paragon/${local.workspace}/env"
    docker_cfg   = "paragon/${local.workspace}/docker-cfg"
    managed_sync = "paragon/${local.workspace}/managed-sync"
    openobserve  = "paragon/${local.workspace}/openobserve"
  }
  runtime_docker_cfg_enabled = var.docker_username != null && var.docker_password != null
}

data "aws_secretsmanager_secret" "env" {
  name = local.runtime_secret_names.env
}

data "aws_secretsmanager_secret_version" "env" {
  secret_id = data.aws_secretsmanager_secret.env.id
}

resource "aws_secretsmanager_secret_version" "env_paragon_overlay" {
  secret_id = data.aws_secretsmanager_secret.env.id
  secret_string = jsonencode(merge(
    jsondecode(data.aws_secretsmanager_secret_version.env.secret_string),
    local.helm_secret_values
  ))
}

data "aws_secretsmanager_secret" "docker_cfg" {
  count = local.runtime_docker_cfg_enabled ? 1 : 0
  name  = local.runtime_secret_names.docker_cfg
}

data "aws_secretsmanager_secret_version" "docker_cfg" {
  count     = local.runtime_docker_cfg_enabled ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.docker_cfg[0].id
}

data "aws_secretsmanager_secret" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0
  name  = local.runtime_secret_names.managed_sync
}

data "aws_secretsmanager_secret_version" "managed_sync" {
  count     = var.managed_sync_enabled ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.managed_sync[0].id
}

resource "aws_secretsmanager_secret_version" "managed_sync_paragon_overlay" {
  count = var.managed_sync_enabled ? 1 : 0

  secret_id = data.aws_secretsmanager_secret.managed_sync[0].id
  secret_string = jsonencode(merge(
    jsondecode(data.aws_secretsmanager_secret_version.managed_sync[0].secret_string),
    module.managed_sync_config[0].config
  ))
}

data "aws_secretsmanager_secret" "openobserve" {
  name = local.runtime_secret_names.openobserve
}

data "aws_secretsmanager_secret_version" "openobserve" {
  secret_id = data.aws_secretsmanager_secret.openobserve.id
}

locals {
  runtime_env_secret_name          = data.aws_secretsmanager_secret.env.name
  runtime_docker_cfg_secret_name   = local.runtime_docker_cfg_enabled ? data.aws_secretsmanager_secret.docker_cfg[0].name : null
  runtime_openobserve_secret_name  = data.aws_secretsmanager_secret.openobserve.name
  runtime_managed_sync_secret_name = var.managed_sync_enabled ? data.aws_secretsmanager_secret.managed_sync[0].name : null
}

# Gate Helm/ESO until Secrets Manager values exist (not just secret metadata).
resource "terraform_data" "runtime_secrets_populated" {
  input = {
    env         = aws_secretsmanager_secret_version.env_paragon_overlay.version_id
    docker_cfg  = local.runtime_docker_cfg_enabled ? data.aws_secretsmanager_secret_version.docker_cfg[0].version_id : null
    openobserve = data.aws_secretsmanager_secret_version.openobserve.version_id
    managed_sync = var.managed_sync_enabled ? (
      aws_secretsmanager_secret_version.managed_sync_paragon_overlay[0].version_id
    ) : null
  }
}
