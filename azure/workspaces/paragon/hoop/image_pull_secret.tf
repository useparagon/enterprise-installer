# hoopagent-chart does not expose imagePullSecrets. Pods inherit pull secrets from
# the hoopagent ServiceAccount when the pod spec omits them.
#
# The chart only renders serviceAccountName when it creates the ServiceAccount itself,
# so Helm has to own the object and Terraform can only patch it. Server-side apply is
# what makes that possible: kubernetes_manifest can only create, never adopt.
resource "kubectl_manifest" "hoopagent_image_pull_secrets" {
  count = var.hoop_enabled ? 1 : 0

  server_side_apply = true
  force_conflicts   = true

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "hoopagent"
      namespace = var.namespace_paragon.id
    }
    imagePullSecrets = [
      { name = var.docker_pull_secret_name }
    ]
  })

  depends_on = [helm_release.hoopagent]
}
