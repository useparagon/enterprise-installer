resource "terraform_data" "validate_gitops" {
  lifecycle {
    precondition {
      condition     = !var.argocd_enabled || (var.infra_eso_role_arn != null && trimspace(var.infra_eso_role_arn) != "")
      error_message = "infra_eso_role_arn is required when argocd_enabled is true."
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

  depends_on = [aws_secretsmanager_secret_version.env_paragon_overlay]
}
