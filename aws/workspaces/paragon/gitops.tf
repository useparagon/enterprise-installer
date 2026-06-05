resource "terraform_data" "validate_gitops" {
  lifecycle {
    precondition {
      condition     = !var.argocd_enabled || (var.infra_eso_role_arn != null && trimspace(var.infra_eso_role_arn) != "")
      error_message = "infra_eso_role_arn is required when argocd_enabled is true."
    }
  }
}
