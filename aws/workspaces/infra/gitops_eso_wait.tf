# Wait for ESO CRDs after the Blueprints Helm release completes. The sleep re-runs when
# the Helm revision changes so retries after a failed ClusterSecretStore apply still wait.
resource "time_sleep" "gitops_eso_crds" {
  count = var.argocd_enabled ? 1 : 0

  create_duration = "120s"

  triggers = {
    eso_revision      = try(tostring(module.eks_blueprints_addons.external_secrets.revision), "0")
    eso_chart_release = try(module.eks_blueprints_addons.external_secrets.version, "")
    eso_chart_version = var.eso_chart_version
  }

  depends_on = [module.eks_blueprints_addons]
}
