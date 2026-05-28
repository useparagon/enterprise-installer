# ESO is installed and IRSA-bound by eks-blueprints-addons (enable_external_secrets).
# The addon creates the IAM role, policy (scoped to the ARNs below), service account,
# and the IRSA annotation. We only supply scoped Secrets Manager ARNs and chart overrides.

locals {
  gitops_eso_namespace = "external-secrets"
  gitops_eso_sa_name   = "external-secrets"

  # Secrets the operator may read. Prefer the concrete secret ARNs; fall back to the
  # per-workspace prefix wildcard when the secrets module has not created them yet.
  gitops_eso_secret_arns = var.argocd_enabled && local.argocd_secrets_ready ? module.secrets[0].secret_arns : [
    "arn:aws:secretsmanager:${var.aws_region}:*:secret:paragon/${local.workspace}/*",
  ]

  gitops_external_secrets = merge(
    {
      name             = "external-secrets"
      namespace        = local.gitops_eso_namespace
      create_namespace = true
      chart_version    = var.eso_chart_version
      skip_crds        = false
      wait             = true
      wait_for_jobs    = true
      timeout          = 600
      values = [yamlencode({
        installCRDs = true
        crds = {
          createClusterSecretStore    = true
          createClusterExternalSecret = true
          createClusterGenerator      = true
          createPushSecret            = true
        }
      })]
    },
    var.eso_addon_overrides
  )
}
