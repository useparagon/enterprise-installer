# Infra workspace owns base Secrets Manager secrets (PARA-21726). This workspace
# reads them. Chart secret keys are published to a separate env-paragon secret
# and merged in Kubernetes by External Secrets.

locals {
  runtime_secret_names = {
    env          = "paragon/${local.workspace}/env"
    env_paragon  = "paragon/${local.workspace}/env-paragon"
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

locals {
  runtime_env_document = jsondecode(data.aws_secretsmanager_secret_version.env.secret_string)
  runtime_chart_only_secret_keys = toset([
    for key in local.chart_secret_keys : key if !contains(local.chart_env_keys, key)
  ])
  # Main-era stacks kept chart secretKeys in the shared env document. Seed them on
  # the first env-paragon write so keys that exist only in Secrets Manager survive.
  runtime_env_paragon_seeded_from_env = {
    for key in local.runtime_chart_only_secret_keys :
    key => tostring(local.runtime_env_document[key])
    if contains(keys(local.runtime_env_document), key) &&
    trimspace(tostring(local.runtime_env_document[key])) != ""
  }
}

# Infra owns paragon/<workspace>/env and replaces that document on every apply.
# Paragon-owned keys live here so that replacement cannot drop them. External
# Secrets reads env first and this secret second; duplicate keys use this value.
resource "aws_secretsmanager_secret" "env_paragon" {
  name                    = local.runtime_secret_names.env_paragon
  description             = "Paragon chart secret keys for ${local.workspace}. Merged over the infra env secret by External Secrets."
  recovery_window_in_days = 30
}

resource "aws_secretsmanager_secret_version" "env_paragon" {
  secret_id = aws_secretsmanager_secret.env_paragon.id
  # Do not copy the infra env document into this secret. helm_secret_values is
  # the chart secretKey set (LICENSE, OAuth, SMTP, service tokens, and any
  # secret endpoint the chart classifies). REDIS_URL is forced on cutover
  # because it is not always present in service-inputs secretKeys.
  secret_string = jsonencode(merge(
    local.runtime_env_paragon_seeded_from_env,
    local.helm_secret_values,
    local.valkey_cutover ? { REDIS_URL = local.default_redis_url } : {}
  ))

  lifecycle {
    precondition {
      condition = !var.valkey_migration || alltrue([
        for role in local.active_redis_required_roles :
        try(local.active_redis_connections[role].host != "" && local.active_redis_connections[role].port > 0, false)
      ])
      error_message = "Valkey cutover requires a valid physical Valkey endpoint for every active role, including shared Managed Sync."
    }

    precondition {
      # Migration pairs are physical instances, not logical application roles.
      # Workflow aliases Cache and Agent OS has its own independent Valkey.
      condition = !var.valkey_migration || !var.redis_enabled || (
        length(setsubtract(
          toset([for role in keys(local.physical_redis_connections) : role if contains(["cache", "queue", "system", "managed_sync"], role)]),
          toset(keys(local.physical_valkey_connections))
        )) == 0 &&
        length(setsubtract(
          toset(keys(local.physical_valkey_connections)),
          toset([for role in keys(local.physical_redis_connections) : role if contains(["cache", "queue", "system", "managed_sync"], role)])
        )) == 0
      )
      error_message = "Physical Redis and Valkey migration pairs must match one-to-one before cutover."
    }

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

# Agent OS reuses the effective Enterprise service-plane credentials.
# In the Paragon and Managed Sync monorepos, these tokens fall back to LICENSE
# when not explicitly provided. Prefer chart values; the infra env secret remains
# a fallback when LICENSE is set only in app_secrets.
locals {
  agent_os_paragon_env_secret  = var.agent_os_enabled ? jsondecode(data.aws_secretsmanager_secret_version.env.secret_string) : {}
  agent_os_managed_sync_config = var.agent_os_enabled ? module.managed_sync_config[0].config : {}

  # Chart values and the Paragon secret are the source for LICENSE. The infra
  # env document is only a fallback for stacks that set it in app_secrets.
  agent_os_license = try(coalesce(
    try(local.helm_secret_values["LICENSE"], null),
    try(local.helm_vars.global.env["LICENSE"], null),
    try(local.agent_os_managed_sync_config.LICENSE, null),
    try(local.agent_os_paragon_env_secret.LICENSE, null),
  ), null)

  # Managed Sync's API_SYNC_ACCESS_TOKEN defaults to LICENSE on Enterprise.
  agent_os_managed_sync_token = try(coalesce(
    try(local.helm_secret_values["API_SYNC_ACCESS_TOKEN"], null),
    try(local.agent_os_managed_sync_config.API_SYNC_ACCESS_TOKEN, null),
    try(local.helm_vars.global.env["API_SYNC_ACCESS_TOKEN"], null),
    try(local.agent_os_paragon_env_secret.API_SYNC_ACCESS_TOKEN, null),
    local.agent_os_license,
  ), null)

  # Zeus and worker-actionkit independently accept explicit tokens and otherwise
  # use LICENSE in the Paragon monorepo. Never copy the monorepo's static dev fallback.
  agent_os_zeus_token = try(coalesce(
    try(local.helm_secret_values["ZEUS_ACCESS_TOKEN"], null),
    try(local.helm_vars.global.env["ZEUS_ACCESS_TOKEN"], null),
    try(local.agent_os_paragon_env_secret.ZEUS_ACCESS_TOKEN, null),
    local.agent_os_license,
  ), null)

  agent_os_actionkit_token = try(coalesce(
    try(local.helm_secret_values["WORKER_ACTIONKIT_ACCESS_TOKEN"], null),
    try(local.helm_vars.global.env["WORKER_ACTIONKIT_ACCESS_TOKEN"], null),
    try(local.agent_os_paragon_env_secret.WORKER_ACTIONKIT_ACCESS_TOKEN, null),
    local.agent_os_license,
  ), null)

  agent_os_app_config_from_paragon = var.agent_os_enabled ? {
    for key, value in {
      MANAGED_SYNC_ACCESS_TOKEN     = local.agent_os_managed_sync_token
      ZEUS_ACCESS_TOKEN             = local.agent_os_zeus_token
      WORKER_ACTIONKIT_ACCESS_TOKEN = local.agent_os_actionkit_token
      LICENSE                       = local.agent_os_license
    } : key => tostring(value)
    if value != null && trimspace(tostring(value)) != ""
  } : {}
}

# Match the Managed Sync flow: infra owns/initially populates these secrets,
# while the paragon workspace overlays app-level values that infra cannot know.
resource "aws_secretsmanager_secret_version" "agent_os_app_paragon_overlay" {
  count = var.agent_os_enabled ? 1 : 0

  secret_id = data.aws_secretsmanager_secret.agent_os_app[0].id
  secret_string = jsonencode(merge(
    jsondecode(data.aws_secretsmanager_secret_version.agent_os_app[0].secret_string),
    local.agent_os_app_config_from_paragon,
    var.agent_os_app_config,
    local.agent_os_file_app_config,
  ))
}

resource "aws_secretsmanager_secret_version" "agent_os_admin_paragon_overlay" {
  count = var.agent_os_enabled ? 1 : 0

  secret_id = data.aws_secretsmanager_secret.agent_os_admin[0].id
  secret_string = jsonencode(merge(
    jsondecode(data.aws_secretsmanager_secret_version.agent_os_admin[0].secret_string),
    var.agent_os_admin_config,
    local.agent_os_file_admin_config,
  ))
}

resource "aws_secretsmanager_secret_version" "agent_os_vendor_paragon_overlay" {
  count = var.agent_os_enabled ? 1 : 0

  secret_id = data.aws_secretsmanager_secret.agent_os_vendor[0].id
  # Merge so an empty tfvars map cannot wipe keys already in Secrets Manager.
  # Operator-provided API keys come from .secure/values.yaml agentOs.secrets.vendor.
  secret_string = jsonencode(merge(
    jsondecode(data.aws_secretsmanager_secret_version.agent_os_vendor[0].secret_string),
    var.agent_os_vendor_config,
    local.agent_os_file_vendor_config,
  ))

  lifecycle {
    precondition {
      condition = try(trimspace(coalesce(
        try(local.agent_os_file_vendor_config.VOYAGE_API_KEY, null),
        try(var.agent_os_vendor_config.VOYAGE_API_KEY, null),
        try(jsondecode(data.aws_secretsmanager_secret_version.agent_os_vendor[0].secret_string).VOYAGE_API_KEY, null),
      )) != "", false)
      error_message = "Agent OS requires VOYAGE_API_KEY. Set agentOs.secrets.vendor.VOYAGE_API_KEY in .secure/values.yaml before enabling agent_os_enabled."
    }
  }
}

data "aws_secretsmanager_secret" "openobserve" {
  name = local.runtime_secret_names.openobserve
}

data "aws_secretsmanager_secret_version" "openobserve" {
  secret_id = data.aws_secretsmanager_secret.openobserve.id
}

locals {
  runtime_env_secret_name          = data.aws_secretsmanager_secret.env.name
  runtime_env_paragon_secret_name  = aws_secretsmanager_secret.env_paragon.name
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
    env_paragon     = aws_secretsmanager_secret_version.env_paragon.version_id
    docker_cfg      = local.runtime_docker_cfg_sync_enabled ? local.runtime_docker_cfg_version_id : null
    openobserve     = data.aws_secretsmanager_secret_version.openobserve.version_id
    agent_os_app    = var.agent_os_enabled ? aws_secretsmanager_secret_version.agent_os_app_paragon_overlay[0].version_id : null
    agent_os_broker = var.agent_os_enabled ? data.aws_secretsmanager_secret_version.agent_os_broker[0].version_id : null
    agent_os_admin  = var.agent_os_enabled ? aws_secretsmanager_secret_version.agent_os_admin_paragon_overlay[0].version_id : null
    agent_os_vendor = var.agent_os_enabled ? aws_secretsmanager_secret_version.agent_os_vendor_paragon_overlay[0].version_id : null
    managed_sync = var.managed_sync_enabled ? (
      aws_secretsmanager_secret_version.managed_sync_paragon_overlay[0].version_id
    ) : null
  }
}

# Existing stacks stored the Paragon overlay as a version of paragon/<workspace>/env.
# Drop that resource from state without deleting the version. Deleting it would
# move AWSCURRENT on the infra secret before External Secrets reads both sources.
removed {
  from = aws_secretsmanager_secret_version.env_paragon_overlay

  lifecycle {
    destroy = false
  }
}
