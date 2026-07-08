# Fixed delay before GitOps Helm releases — kubectl manifests also depend on
# helm_release.external_secrets so CRDs exist before ClusterSecretStore apply.

resource "time_sleep" "eso_crds" {
  count = local.enabled ? 1 : 0

  create_duration = "120s"

  depends_on = [helm_release.external_secrets]

  triggers = {
    eso_release = helm_release.external_secrets[0].id
  }
}
