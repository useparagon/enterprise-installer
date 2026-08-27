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

  # Chart cannot set imagePullSecrets. awk injects them onto the SA Helm creates
  # so pods inherit docker-cfg at create time (before atomic/wait).
  postrender {
    binary_path = "awk"
    args = [
      "-v", "secret=${var.docker_pull_secret_name}",
      "/^kind: ServiceAccount$/ { print; print \"imagePullSecrets:\"; print \"- name: \" secret; next } { print }",
    ]
  }

  dynamic "set" {
    for_each = try(aws_iam_role.hoop_support[0].arn, null) != null ? [1] : []
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.hoop_support[0].arn
    }
  }
}
