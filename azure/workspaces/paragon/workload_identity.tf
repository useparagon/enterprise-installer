data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "${local.workspace}-external-secrets"
  location            = local.infra_vars.resource_group.value.location
  resource_group_name = local.infra_vars.resource_group.value.name
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  name                      = "external-secrets"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url
  subject                   = "system:serviceaccount:external-secrets:external-secrets"
  user_assigned_identity_id = azurerm_user_assigned_identity.external_secrets.id
}

resource "time_sleep" "external_secrets_federation" {
  create_duration = "90s"

  depends_on = [azurerm_federated_identity_credential.external_secrets]

  triggers = {
    federated_credential_id = azurerm_federated_identity_credential.external_secrets.id
  }
}

resource "azurerm_key_vault_access_policy" "external_secrets" {
  key_vault_id = data.azurerm_key_vault.paragon.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.external_secrets.principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Agent OS uses a dedicated workload identity for its private blob container.
resource "azurerm_user_assigned_identity" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name                = "${local.workspace}-agent-os"
  location            = local.infra_vars.resource_group.value.location
  resource_group_name = local.infra_vars.resource_group.value.name
}

resource "azurerm_federated_identity_credential" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name                      = "agent-os"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url
  subject                   = "system:serviceaccount:paragon:agent-os"
  user_assigned_identity_id = azurerm_user_assigned_identity.agent_os[0].id
}

# Container scope keeps Agent OS blob permissions isolated from other workloads.
resource "azurerm_role_assignment" "agent_os_storage" {
  count = var.agent_os_enabled ? 1 : 0

  scope                            = local.agent_os_handoff.container_id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.agent_os[0].principal_id
  skip_service_principal_aad_check = true
}
