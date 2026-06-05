resource "terraform_data" "managed_ingress_controller_ready" {
  count = var.install_ingress_controller ? 1 : 0

  input = helm_release.ingress[0].id

  depends_on = [helm_release.ingress[0]]
}

resource "terraform_data" "external_ingress_controller_ready" {
  count = var.install_ingress_controller ? 0 : 1

  input = var.cluster_name
}
