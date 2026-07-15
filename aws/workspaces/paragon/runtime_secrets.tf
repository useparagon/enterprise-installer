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
  runtime_docker_cfg_json = jsonencode({
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

data "aws_secretsmanager_secret" "env" {
  name = local.runtime_secret_names.env
}

data "aws_secretsmanager_secret_version" "env" {
  secret_id = data.aws_secretsmanager_secret.env.id
}

resource "aws_secretsmanager_secret_version" "env_paragon_overlay" {
  secret_id = data.aws_secretsmanager_secret.env.id
  # Infra wins on conflicts so chart-derived redis/postgres wiring (e.g. WORKFLOW_REDIS_*
  # falling back to cache) cannot clobber infra's managed_sync mapping.
  secret_string = jsonencode(merge(
    local.helm_secret_values,
    jsondecode(data.aws_secretsmanager_secret_version.env.secret_string)
  ))
}

data "aws_secretsmanager_secret" "docker_cfg" {
  name = local.runtime_secret_names.docker_cfg
}

data "aws_secretsmanager_secret_version" "docker_cfg" {
  secret_id = data.aws_secretsmanager_secret.docker_cfg.id
}

locals {
  runtime_docker_cfg_from_infra = try(
    keys(jsondecode(jsondecode(data.aws_secretsmanager_secret_version.docker_cfg.secret_string).dockerconfigjson).auths),
    []
  )
  runtime_docker_cfg_has_infra_auths = length(local.runtime_docker_cfg_from_infra) > 0
  runtime_docker_cfg_needs_paragon_overlay = (
    local.runtime_docker_cfg_enabled &&
    !local.runtime_docker_cfg_has_infra_auths
  )
  # Sync into the cluster only when Terraform should create the pull secret.
  # create_docker_pull_secret=false is the Artifactory/proxy path where a
  # customer-pre-provisioned secret is referenced via helm imagePullSecrets.
  # Sync when paragon tfvars have credentials OR infra already wrote auths.
  runtime_docker_cfg_sync_enabled = var.create_docker_pull_secret && (
    local.runtime_docker_cfg_enabled || local.runtime_docker_cfg_has_infra_auths
  )
}

resource "aws_secretsmanager_secret_version" "docker_cfg_paragon_overlay" {
  count = local.runtime_docker_cfg_needs_paragon_overlay ? 1 : 0

  secret_id     = data.aws_secretsmanager_secret.docker_cfg.id
  secret_string = local.runtime_docker_cfg_json
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
  runtime_docker_cfg_secret_name   = local.runtime_docker_cfg_sync_enabled ? data.aws_secretsmanager_secret.docker_cfg.name : null
  runtime_openobserve_secret_name  = data.aws_secretsmanager_secret.openobserve.name
  runtime_managed_sync_secret_name = var.managed_sync_enabled ? data.aws_secretsmanager_secret.managed_sync[0].name : null
  runtime_docker_cfg_version_id = local.runtime_docker_cfg_needs_paragon_overlay ? (
    aws_secretsmanager_secret_version.docker_cfg_paragon_overlay[0].version_id
  ) : data.aws_secretsmanager_secret_version.docker_cfg.version_id
}

# Gate Helm/ESO until Secrets Manager values exist (not just secret metadata).
resource "terraform_data" "runtime_secrets_populated" {
  input = {
    env         = aws_secretsmanager_secret_version.env_paragon_overlay.version_id
    docker_cfg  = local.runtime_docker_cfg_sync_enabled ? local.runtime_docker_cfg_version_id : null
    openobserve = data.aws_secretsmanager_secret_version.openobserve.version_id
    managed_sync = var.managed_sync_enabled ? (
      aws_secretsmanager_secret_version.managed_sync_paragon_overlay[0].version_id
    ) : null
  }
}
