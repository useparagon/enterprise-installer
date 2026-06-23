# Workload Identity managed identities for ESO and ALB Controller.

resource "azurerm_user_assigned_identity" "eso" {
  count = local.enabled ? 1 : 0

  name                = "${var.workspace}-eso"
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

resource "azurerm_federated_identity_credential" "eso" {
  count = local.enabled ? 1 : 0

  name                      = "${var.workspace}-eso"
  user_assigned_identity_id = azurerm_user_assigned_identity.eso[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${local.gitops_eso_namespace}:${local.gitops_eso_sa_name}"
}

resource "azurerm_key_vault_access_policy" "eso" {
  count = local.enabled ? 1 : 0

  key_vault_id = var.key_vault_id
  tenant_id    = var.azure_tenant_id
  object_id    = azurerm_user_assigned_identity.eso[0].principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_user_assigned_identity" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name                = "${var.workspace}-edns"
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

resource "azurerm_federated_identity_credential" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name                      = "${var.workspace}-edns"
  user_assigned_identity_id = azurerm_user_assigned_identity.external_dns[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:external-dns:external-dns"
}

resource "azurerm_role_assignment" "external_dns_dns_zone" {
  count = local.gitops_ingress_enabled ? 1 : 0

  role_definition_name = "DNS Zone Contributor"
  scope                = azurerm_dns_zone.paragon[0].id
  principal_id         = azurerm_user_assigned_identity.external_dns[0].principal_id
}

resource "azurerm_user_assigned_identity" "alb_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name                = "${var.workspace}-alb-ctrl"
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

resource "azurerm_federated_identity_credential" "alb_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name                      = "${var.workspace}-alb-ctrl"
  user_assigned_identity_id = azurerm_user_assigned_identity.alb_controller[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}

resource "azurerm_role_assignment" "alb_controller_node_rg" {
  count = local.gitops_ingress_enabled ? 1 : 0

  role_definition_name = "Network Contributor"
  scope                = "/subscriptions/${var.azure_subscription_id}/resourceGroups/${var.azure_node_resource_group}"
  principal_id         = azurerm_user_assigned_identity.alb_controller[0].principal_id
}
