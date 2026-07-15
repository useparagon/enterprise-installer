output "ingress_ready" {
  value = one(compact([
    try(terraform_data.managed_ingress_controller_ready[0].id, null),
    try(terraform_data.external_ingress_controller_ready[0].id, null),
  ]))
}

output "release_ingress" {
  value = try(helm_release.ingress[0], null)
}

output "release_paragon_on_prem" {
  value = helm_release.paragon_on_prem
}

output "namespace_paragon" {
  value = var.argocd_enabled ? data.kubernetes_namespace.paragon[0] : kubernetes_namespace.paragon[0]
}

output "openobserve_email" {
  value     = local.openobserve_email
  sensitive = true
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}
