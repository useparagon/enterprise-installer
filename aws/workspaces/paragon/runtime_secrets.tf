# Infra workspace owns base Secrets Manager secrets (PARA-21726). This workspace
# reads them and writes overlay versions for chart-specific keys only.

locals {
  runtime_secret_names = {
    env          = "paragon/${local.workspace}/env"
    docker_cfg   = "paragon/${local.workspace}/docker-cfg"
    managed_sync = "paragon/${local.workspace}/managed-sync"
    openobserve  = "paragon/${local.workspace}/openobserve"
  }
  # coalesce(null, "") errors because coalesce skips empty strings as well as null.
  runtime_docker_username = trimspace(var.docker_username != null ? var.docker_username : "")
  runtime_docker_password = trimspace(var.docker_password != null ? var.docker_password : "")

  # Blank credentials produce a well-formed but unusable pull secret
  # (auth = base64(":")), which fails image pulls with insufficient_scope
  # instead of failing the apply, so blank is treated the same as unset.
  runtime_docker_cfg_enabled = local.runtime_docker_username != "" && local.runtime_docker_password != ""

  runtime_docker_cfg_paragon_auths = local.runtime_docker_cfg_enabled ? {
    (var.docker_registry_server) = {
      username = local.runtime_docker_username
      password = local.runtime_docker_password
      email    = var.docker_email != null ? var.docker_email : ""
      auth     = base64encode("${local.runtime_docker_username}:${local.runtime_docker_password}")
    }
  } : {}
}

data "aws_secretsmanager_secret" "env" {
  name = local.runtime_secret_names.env
}

data "aws_secretsmanager_secret_version" "env" {
  secret_id = data.aws_secretsmanager_secret.env.id
}

resource "aws_secretsmanager_secret_version" "env_paragon_overlay" {
  secret_id = data.aws_secretsmanager_secret.env.id
  # Infra owns the base secret and wins on conflicts; this workspace only overlays
  # chart-specific keys that infra does not compute.
  secret_string = jsonencode(merge(
    local.helm_secret_values,
    jsondecode(data.aws_secretsmanager_secret_version.env.secret_string)
  ))

  lifecycle {
    precondition {
      condition     = length(local.chart_service_inputs) > 0
      error_message = "No charts/**/files/service-inputs.json under ${path.root}/charts. Run ./prepare.sh -p aws before apply so secretKeys/envKeys can be classified."
    }
  }
}

data "aws_secretsmanager_secret" "docker_cfg" {
  name = local.runtime_secret_names.docker_cfg
}

data "aws_secretsmanager_secret_version" "docker_cfg" {
  secret_id = data.aws_secretsmanager_secret.docker_cfg.id
}

locals {
  runtime_docker_cfg_base_auths = try(
    jsondecode(jsondecode(data.aws_secretsmanager_secret_version.docker_cfg.secret_string).dockerconfigjson).auths,
    {}
  )
  # An entry missing a username or password cannot pull images, so it does not
  # count as populated and must not suppress this workspace's credentials.
  runtime_docker_cfg_usable_base_auths = {
    for registry, auth in local.runtime_docker_cfg_base_auths : registry => auth
    if trimspace(try(auth.username, "")) != "" && trimspace(try(auth.password, "")) != ""
  }
  runtime_docker_cfg_has_infra_auths = length(keys(local.runtime_docker_cfg_usable_base_auths)) > 0

  # Other registries infra may own are preserved; this workspace only owns the
  # entry for its own registry.
  runtime_docker_cfg_json = jsonencode({
    dockerconfigjson = jsonencode({
      auths = merge(
        local.runtime_docker_cfg_usable_base_auths,
        local.runtime_docker_cfg_paragon_auths
      )
    })
  })

  # Sync into the cluster only when Terraform should create the pull secret.
  # create_docker_pull_secret=false is the Artifactory/proxy path where a
  # customer-pre-provisioned secret is referenced via helm imagePullSecrets.
  # Sync when paragon tfvars have credentials OR infra already wrote auths.
  runtime_docker_cfg_sync_enabled = var.create_docker_pull_secret && (
    local.runtime_docker_cfg_enabled || local.runtime_docker_cfg_has_infra_auths
  )
}

# count must not depend on the auths this resource writes: gating it on the
# current secret value made the overlay delete itself on the following plan,
# reverting AWSCURRENT to the infra base version with nothing to repopulate it.
resource "aws_secretsmanager_secret_version" "docker_cfg_paragon_overlay" {
  count = local.runtime_docker_cfg_enabled ? 1 : 0

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
  runtime_docker_cfg_version_id = local.runtime_docker_cfg_enabled ? (
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
