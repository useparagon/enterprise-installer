# Key Vault secrets for GitOps + OpenObserve credentials + CRD readiness wait.
# All secrets are created inside the module so the argocd_enabled feature flag
# at the module call site is the single gate for all cloud-side ArgoCD resources.

locals {
  secrets_ready = (
    trimspace(var.paragon_domain) != "" &&
    var.docker_username != null && var.docker_username != "" &&
    var.docker_password != null && var.docker_password != ""
  )

  openobserve_credentials = {
    email    = "${random_string.openobserve_email.result}@useparagon.com"
    password = random_password.openobserve_password.result
  }
}

resource "random_string" "openobserve_email" {
  length  = 8
  special = false
  upper   = false
}

resource "random_password" "openobserve_password" {
  length  = 32
  special = true
}

# Wait for the cluster API to be fully stable before Helm installs attempt
# to apply CRD-backed resources. Triggered by cluster_name so a cluster
# replacement causes the wait to re-run.
resource "time_sleep" "eso_crds" {
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
