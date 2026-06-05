resource "terraform_data" "managed_ingress_controller_ready" {
  count = var.install_ingress_controller ? 1 : 0

  input = helm_release.ingress[0].id

  depends_on = [helm_release.ingress[0]]
}

resource "terraform_data" "external_ingress_controller_ready" {
  count = var.install_ingress_controller ? 0 : 1

  input = var.infra_gitops_ready
}

resource "terraform_data" "validate_ingress_ready" {
  lifecycle {
    precondition {
      condition     = var.install_ingress_controller || (var.infra_gitops_ready != null && trimspace(var.infra_gitops_ready) != "")
      error_message = "infra_gitops_ready is required when install_ingress_controller is false."
    }
  }
}
