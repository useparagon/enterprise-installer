output "alb_lookup_gate" {
  description = "Apply-time gate for ALB data lookups. Stable after first apply so Route53/Grafana do not inherit unknown Helm attributes."
  value       = terraform_data.alb_lookup_gate
}

output "namespace_paragon" {
  value = kubernetes_namespace.paragon
}

output "openobserve_email" {
  value     = local.openobserve_email
  sensitive = true
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}
