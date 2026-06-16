# Key Vault secrets for GitOps + OpenObserve credentials + CRD readiness wait.

locals {
  openobserve_credentials = local.secrets_ready ? {
    email    = "${random_string.openobserve_email[0].result}@useparagon.com"
    password = random_password.openobserve_password[0].result
  } : null
}

resource "random_string" "openobserve_email" {
  count = local.secrets_ready ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

resource "random_password" "openobserve_password" {
  count = local.secrets_ready ? 1 : 0

  length  = 32
  special = true
}

resource "time_sleep" "eso_crds" {
  count = local.enabled ? 1 : 0

  create_duration = "120s"

  triggers = {
    cluster_name = var.cluster_name
  }
}

resource "azurerm_key_vault_secret" "env" {
  count = local.secrets_ready ? 1 : 0

  name         = "env"
  key_vault_id = var.key_vault_id
  value        = jsonencode(var.env_config)
}

resource "azurerm_key_vault_secret" "docker_cfg" {
  count = local.secrets_ready ? 1 : 0

  name         = "docker-cfg"
  key_vault_id = var.key_vault_id
  value = jsonencode({
    dockerconfigjson = jsonencode({
      auths = {
        (var.docker_registry_server) = {
          username = var.docker_username
          password = var.docker_password
          email    = coalesce(var.docker_email, "")
          auth     = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  })
}

resource "azurerm_key_vault_secret" "managed_sync" {
  count = local.secrets_ready && var.managed_sync_config != null ? 1 : 0

  name         = "managed-sync"
  key_vault_id = var.key_vault_id
  value        = jsonencode(var.managed_sync_config)
}

resource "azurerm_key_vault_secret" "openobserve" {
  count = local.secrets_ready ? 1 : 0

  name         = "openobserve"
  key_vault_id = var.key_vault_id
  value = jsonencode({
    ZO_ROOT_USER_EMAIL    = local.openobserve_credentials.email
    ZO_ROOT_USER_PASSWORD = local.openobserve_credentials.password
  })
}
