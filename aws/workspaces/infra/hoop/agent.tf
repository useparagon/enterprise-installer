resource "helm_release" "hoopagent" {
  name       = "hoopagent"
  repository = "oci://ghcr.io/hoophq/helm-charts"
  chart      = "hoopagent-chart"
  version    = var.hoop_version
  namespace  = var.namespace

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
    name  = "image.tag"
    value = var.hoop_version
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  dynamic "set" {
    for_each = aws_iam_role.hoop_support[*].arn
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = set.value
    }
  }
}
