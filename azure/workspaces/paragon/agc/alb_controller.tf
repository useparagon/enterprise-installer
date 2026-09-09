resource "kubernetes_namespace" "alb" {
  count = var.enabled ? 1 : 0

  metadata {
    name = local.alb_controller_ns

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ALB controller: Gateway API -> AGC data plane. Chart ships Gateway API CRDs.
resource "helm_release" "alb_controller" {
  count = var.enabled ? 1 : 0

  name       = "alb-controller"
  namespace  = kubernetes_namespace.alb[0].metadata[0].name
  repository = "oci://mcr.microsoft.com/application-lb/charts"
  chart      = "alb-controller"
  version    = var.alb_controller_version

  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "albController.namespace"
    value = local.alb_controller_ns
  }

  set {
    name  = "albController.podIdentity.clientID"
    value = azurerm_user_assigned_identity.alb[0].client_id
  }

  depends_on = [
    azurerm_federated_identity_credential.alb,
    azurerm_role_assignment.alb_config_manager,
    azurerm_role_assignment.alb_subnet,
    azurerm_role_assignment.alb_reader,
    azurerm_application_load_balancer_subnet_association.this,
  ]
}
