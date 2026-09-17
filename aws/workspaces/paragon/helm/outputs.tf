output "release_ingress" {
  description = "Ingress controller Helm release (ALB creation ordering for service DNS)."
  value       = helm_release.ingress
}

output "release_paragon_logging" {
  description = "Logging Helm release (ALB creation ordering for service DNS)."
  value       = helm_release.paragon_logging
}

output "release_paragon_on_prem" {
  description = "Paragon on-prem Helm release (ALB creation ordering for service DNS)."
  value       = helm_release.paragon_on_prem
}

output "alb_arn" {
  description = "The ARN of the application load balancer."
  value       = data.aws_lb.load_balancer.arn
}

output "namespace_paragon" {
  value = kubernetes_namespace.paragon
}

output "namespace_agent_os" {
  value = var.agent_os_enabled ? kubernetes_namespace.agent_os[0] : null
}

output "openobserve_email" {
  value     = local.openobserve_email
  sensitive = true
}

output "openobserve_password" {
  value     = local.openobserve_password
  sensitive = true
}
