output "load_balancer" {
  value = google_compute_global_address.loadbalancer.address
}

output "openobserve_email" {
  value     = local.openobserve_email
  sensitive = true
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}

output "namespace_paragon" {
  value = kubernetes_namespace_v1.paragon
}

# Lets callers that pull private images order themselves after the ESO sync.
output "docker_cfg_ready" {
  value = try(data.kubernetes_secret.docker_cfg[0].id, terraform_data.eso_secrets_gate.id)
}
