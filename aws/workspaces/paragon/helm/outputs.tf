output "release_ingress" {
  value = helm_release.ingress
}

output "release_paragon_on_prem" {
  value = helm_release.paragon_on_prem
}

output "namespace_paragon" {
  value = kubernetes_namespace.paragon
}

# Lets callers that pull private images order themselves after the ESO sync.
output "docker_cfg_ready" {
  value = try(data.kubernetes_secret.docker_cfg[0].id, terraform_data.eso_secrets_gate.id)
}

output "openobserve_email" {
  value     = local.openobserve_email
  sensitive = true
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}
