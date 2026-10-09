locals {
  runtime_secret_names = {
    env          = "env"
    docker_cfg   = "docker-cfg"
    managed_sync = "managed-sync"
    openobserve  = "openobserve"
  }

  # .secure/values.yaml owns customer overrides, not Helm templates.
  # Never pass agentOs.secrets to the chart; ESO loads them from Key Vault.
  agent_os_file_secrets = try(local.helm_vars.agentOs.secrets, {})
  agent_os_file_app_config = {
    for key, value in try(local.agent_os_file_secrets.app, {}) :
    key => tostring(value) if value != null
  }
  agent_os_file_admin_config = {
    for key, value in try(local.agent_os_file_secrets.admin, {}) :
    key => tostring(value) if value != null
  }
  agent_os_file_vendor_config = {
    for key, value in try(local.agent_os_file_secrets.vendor, {}) :
    key => tostring(value) if value != null && trimspace(tostring(value)) != ""
  }

  # Reuse the tokens Paragon and Managed Sync actually deploy. Both services
  # fall back to LICENSE when no dedicated access token was supplied.
  agent_os_managed_sync_config = var.agent_os_enabled ? module.managed_sync_config[0].config : {}
  agent_os_paragon_env         = var.agent_os_enabled ? local.helm_secret_values : {}

  agent_os_license = try(coalesce(
    try(local.agent_os_paragon_env.LICENSE, null),
    try(local.agent_os_managed_sync_config.LICENSE, null),
    try(local.helm_vars.global.env["LICENSE"], null),
  ), null)

  agent_os_managed_sync_token = try(coalesce(
    try(local.agent_os_managed_sync_config.API_SYNC_ACCESS_TOKEN, null),
    try(local.agent_os_paragon_env.API_SYNC_ACCESS_TOKEN, null),
    try(local.helm_vars.global.env["API_SYNC_ACCESS_TOKEN"], null),
    local.agent_os_license,
  ), null)

  agent_os_zeus_token = try(coalesce(
    try(local.agent_os_paragon_env.ZEUS_ACCESS_TOKEN, null),
    try(local.helm_vars.global.env["ZEUS_ACCESS_TOKEN"], null),
    local.agent_os_license,
  ), null)

  agent_os_actionkit_token = try(coalesce(
    try(local.agent_os_paragon_env.WORKER_ACTIONKIT_ACCESS_TOKEN, null),
    try(local.helm_vars.global.env["WORKER_ACTIONKIT_ACCESS_TOKEN"], null),
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

resource "azurerm_key_vault_secret" "env" {
  name         = local.runtime_secret_names.env
  key_vault_id = data.azurerm_key_vault.paragon.id
  value        = jsonencode(local.helm_secret_values)

  lifecycle {
    precondition {
      condition     = length(local.chart_service_inputs) > 0
      error_message = "No charts/**/files/service-inputs.json under ${path.root}/charts. Run ./prepare.sh -p azure before apply so secretKeys/envKeys can be classified."
    }
    precondition {
      condition     = length(local.helm_secret_values) > 0
      error_message = "Paragon env secret would be empty after chart secretKeys split. Confirm prepare.sh charts and infra-backed helm_values contain postgres/redis credentials."
    }
    precondition {
      condition     = try(local.infra_vars.redis.value.cache.host, "") != ""
      error_message = "Neither `redis` nor `redis-managed` has a usable cache.host. Provide one via Key Vault or infra_json (same JSON shape as installer-managed Redis) before applying this workspace."
    }
  }
}

resource "azurerm_key_vault_secret" "docker_cfg" {
  # Skip when create_docker_pull_secret=false (Artifactory/proxy: pre-provisioned k8s secret).
  count = var.create_docker_pull_secret && var.docker_username != null && var.docker_password != null ? 1 : 0

  name         = local.runtime_secret_names.docker_cfg
  key_vault_id = data.azurerm_key_vault.paragon.id
  value = jsonencode({
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

resource "azurerm_key_vault_secret" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name         = local.runtime_secret_names.managed_sync
  key_vault_id = data.azurerm_key_vault.paragon.id
  value        = jsonencode(module.managed_sync_config[0].config)
}

# Agent OS follows the Managed Sync ownership pattern on Azure: infra publishes
# resource-derived values through its handoff, and the paragon workspace owns the
# application secrets that ESO syncs into Kubernetes.
resource "azurerm_key_vault_secret" "agent_os_app" {
  count = var.agent_os_enabled ? 1 : 0

  name         = "agent-os-app"
  key_vault_id = data.azurerm_key_vault.paragon.id
  value = jsonencode(merge(
    local.agent_os_handoff.app_config,
    local.agent_os_app_config_from_paragon,
    var.agent_os_app_config,
    local.agent_os_file_app_config,
  ))
}

resource "azurerm_key_vault_secret" "agent_os_admin" {
  count = var.agent_os_enabled ? 1 : 0

  name         = "agent-os-admin"
  key_vault_id = data.azurerm_key_vault.paragon.id
  value = jsonencode(merge(
    local.agent_os_handoff.admin_config,
    var.agent_os_admin_config,
    local.agent_os_file_admin_config,
  ))
}

resource "azurerm_key_vault_secret" "agent_os_vendor" {
  count = var.agent_os_enabled ? 1 : 0

  name         = "agent-os-vendor"
  key_vault_id = data.azurerm_key_vault.paragon.id
  value = jsonencode(merge(
    var.agent_os_vendor_config,
    local.agent_os_file_vendor_config,
  ))

  # Operator-owned API keys (Voyage, extraction, etc.). Tfvars or
  # agentOs.secrets.vendor seed create; subsequent rotations stay out of band.
  lifecycle {
    ignore_changes = [value]
  }
}

resource "azurerm_key_vault_secret" "openobserve" {
  count = 1

  name         = local.runtime_secret_names.openobserve
  key_vault_id = data.azurerm_key_vault.paragon.id
  value = jsonencode({
    ZO_ROOT_USER_EMAIL         = local.openobserve_email
    ZO_ROOT_USER_PASSWORD      = local.openobserve_password
    AZURE_STORAGE_ACCOUNT_NAME = local.storage_output.root_user
    AZURE_STORAGE_ACCOUNT_KEY  = local.storage_output.root_password
  })
}
