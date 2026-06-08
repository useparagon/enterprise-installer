# Workload Identity managed identities for ESO and ALB Controller.
# These are created inside the module so all ArgoCD cloud resources are
# encapsulated behind the argocd_enabled feature flag.

locals {
  gitops_eso_namespace   = "external-secrets"
  gitops_eso_sa_name     = "external-secrets"
  gitops_ingress_enabled = trimspace(var.paragon_domain) != ""
}

# ---------------------------------------------------------------------------
# External Secrets Operator — Workload Identity
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "eso" {
  name                = "${var.workspace}-eso"
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

resource "azurerm_federated_identity_credential" "eso" {
  name                = "${var.workspace}-eso"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.eso.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${local.gitops_eso_namespace}:${local.gitops_eso_sa_name}"
}

resource "azurerm_key_vault_access_policy" "eso" {
  key_vault_id = var.key_vault_id
  tenant_id    = var.azure_tenant_id
  object_id    = azurerm_user_assigned_identity.eso.principal_id

  secret_permissions = ["Get", "List"]
}

# ---------------------------------------------------------------------------
# ALB Controller — Workload Identity (Application Gateway for Containers)
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "alb_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name                = "${var.workspace}-alb-ctrl"
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

resource "azurerm_federated_identity_credential" "alb_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name                = "${var.workspace}-alb-ctrl"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.alb_controller[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}

resource "azurerm_role_assignment" "alb_controller_node_rg" {
  count = local.gitops_ingress_enabled ? 1 : 0

  role_definition_name = "Network Contributor"
  scope                = "/subscriptions/${var.azure_subscription_id}/resourceGroups/${var.azure_node_resource_group}"
  principal_id         = azurerm_user_assigned_identity.alb_controller[0].principal_id
}
