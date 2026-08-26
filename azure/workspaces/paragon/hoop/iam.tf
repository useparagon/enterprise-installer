locals {
  hoop_workload_identity_enabled = var.hoop_enabled && trimspace(var.oidc_issuer_url) != ""
}

# User-assigned identity for Hoop agent with subscription Reader (az CLI troubleshooting).
resource "azurerm_user_assigned_identity" "hoop_support" {
  count = local.hoop_workload_identity_enabled ? 1 : 0

  name                = "${var.workspace}-hoop-support"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
}

resource "azurerm_federated_identity_credential" "hoop_support" {
  count = local.hoop_workload_identity_enabled ? 1 : 0

  name                = "${var.workspace}-hoop-support"
  resource_group_name = var.resource_group.name
  parent_id           = azurerm_user_assigned_identity.hoop_support[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace_paragon.id}:hoopagent"
}

resource "azurerm_role_assignment" "hoop_support" {
  count = local.hoop_workload_identity_enabled ? 1 : 0

  scope                            = "/subscriptions/${var.azure_subscription_id}"
  role_definition_name             = "Reader"
  principal_id                     = azurerm_user_assigned_identity.hoop_support[0].principal_id
  skip_service_principal_aad_check = true
}
