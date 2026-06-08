resource "terraform_data" "infra_gitops_applied" {
  count = var.argocd_enabled ? 1 : 0

  input = var.infra_gitops_ready
}

resource "terraform_data" "validate_gitops" {
  lifecycle {
    precondition {
      condition     = !var.argocd_enabled || (var.infra_eso_role_arn != null && trimspace(var.infra_eso_role_arn) != "")
      error_message = "infra_eso_role_arn is required when argocd_enabled is true."
    }
    precondition {
      condition     = !var.argocd_enabled || (var.infra_gitops_ready != null && trimspace(var.infra_gitops_ready) != "")
      error_message = "infra_gitops_ready is required when argocd_enabled is true (set after infra GitOps bootstrap applies)."
    }
  }
}

resource "kubernetes_annotations" "paragon_env_eso_force_sync" {
  count = var.argocd_enabled ? 1 : 0

  api_version = "external-secrets.io/v1beta1"
  kind        = "ExternalSecret"

  metadata {
    name      = "paragon-secrets"
    namespace = "paragon"
  }

  annotations = {
    "force-sync" = aws_secretsmanager_secret_version.env_paragon_overlay[0].version_id
  }

  depends_on = [
    aws_secretsmanager_secret_version.env_paragon_overlay,
    terraform_data.infra_gitops_applied,
  ]
}
