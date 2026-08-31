# Hoop agent deployment
resource "helm_release" "hoopagent" {
  count = var.hoop_enabled ? 1 : 0

  name       = "hoopagent"
  repository = "oci://ghcr.io/hoophq/helm-charts"
  chart      = "hoopagent-chart"
  version    = var.hoop_version
  namespace  = var.namespace_paragon.id

  cleanup_on_fail  = true
  create_namespace = false
  atomic           = true
  verify           = false
  timeout          = 300

  set {
    name  = "config.HOOP_KEY"
    value = "grpcs://${coalesce(var.hoop_agent_name, var.organization)}:${var.hoop_key}@${var.hoop_server}?mode=standard"
  }

  set {
    name  = "image.repository"
    value = var.hoop_image_repository
  }

  set {
    name  = "image.tag"
    value = var.hoop_image_tag
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  dynamic "set" {
    for_each = try(azurerm_user_assigned_identity.hoop_support[0].client_id, null) != null ? [1] : []
    content {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
      value = azurerm_user_assigned_identity.hoop_support[0].client_id
    }
  }
}
