data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# User-assigned identity for the ALB controller (workload identity).
resource "azurerm_user_assigned_identity" "alb" {
  count = var.enabled ? 1 : 0

  name                = "${var.workspace}-alb"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Federate AKS OIDC issuer to the ALB controller ServiceAccount.
resource "azurerm_federated_identity_credential" "alb" {
  count = var.enabled ? 1 : 0

  name                = "${var.workspace}-alb"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.alb[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url
  subject             = "system:serviceaccount:${local.alb_controller_ns}:${local.alb_controller_sa}"
}

# Reader so the controller can discover the ALB and subnet.
resource "azurerm_role_assignment" "alb_reader" {
  count = var.enabled ? 1 : 0

  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.alb[0].principal_id
}

# Network Contributor on the association subnet for AGC data-plane join.
resource "azurerm_role_assignment" "alb_subnet" {
  count = var.enabled ? 1 : 0

  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.alb[0].principal_id
}

# Lets the controller configure this ALB resource.
resource "azurerm_role_assignment" "alb_config_manager" {
  count = var.enabled ? 1 : 0

  scope                = azurerm_application_load_balancer.this[0].id
  role_definition_name = "AppGw for Containers Configuration Manager"
  principal_id         = azurerm_user_assigned_identity.alb[0].principal_id
}

# Application Gateway for Containers traffic controller.
resource "azurerm_application_load_balancer" "this" {
  count = var.enabled ? 1 : 0

  name                = "${var.workspace}-agc"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_application_load_balancer_subnet_association" "this" {
  count = var.enabled ? 1 : 0

  name                         = "${var.workspace}-agc-assoc"
  application_load_balancer_id = azurerm_application_load_balancer.this[0].id
  subnet_id                    = var.subnet_id
  tags                         = var.tags
}

# Attach the WAF policy from the waf module to AGC.
resource "azurerm_application_load_balancer_security_policy" "waf" {
  count = var.enabled && var.waf_enabled ? 1 : 0

  name                               = "${var.workspace}-agc-waf"
  application_load_balancer_id       = azurerm_application_load_balancer.this[0].id
  location                           = var.location
  web_application_firewall_policy_id = var.waf_policy_id
  tags                               = var.tags
}
