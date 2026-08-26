# hoopagent-chart does not expose imagePullSecrets. Pods inherit pull secrets from
# the hoopagent ServiceAccount when the pod spec omits them.
resource "kubernetes_manifest" "hoopagent_image_pull_secrets" {
  count = var.hoop_enabled ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "hoopagent"
      namespace = var.namespace_paragon.id
    }
    imagePullSecrets = [
      { name = var.docker_pull_secret_name }
    ]
  }

  field_manager {
    name            = "terraform-docker-cfg"
    force_conflicts = true
  }

  computed_fields = [
    "metadata.annotations",
    "metadata.labels",
    "secrets",
    "automountServiceAccountToken",
  ]

  depends_on = [helm_release.hoopagent]
}
