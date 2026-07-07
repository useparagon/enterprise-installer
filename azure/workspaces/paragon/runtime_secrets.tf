locals {
  runtime_secret_names = {
    env          = "env"
    docker_cfg   = "docker-cfg"
    managed_sync = "managed-sync"
    openobserve  = "openobserve"
  }
}

resource "azurerm_key_vault_secret" "env" {
  name         = local.runtime_secret_names.env
  key_vault_id = data.azurerm_key_vault.paragon.id
  value        = jsonencode(local.helm_secret_values)
}

resource "azurerm_key_vault_secret" "docker_cfg" {
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

resource "azurerm_key_vault_secret" "openobserve" {
  count = 1

  name         = local.runtime_secret_names.openobserve
  key_vault_id = data.azurerm_key_vault.paragon.id
  value = jsonencode({
    ZO_ROOT_USER_EMAIL    = local.openobserve_email
    ZO_ROOT_USER_PASSWORD = local.openobserve_password
  })
}
