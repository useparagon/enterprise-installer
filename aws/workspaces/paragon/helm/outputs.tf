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

output "alb_dns_name" {
  description = "DNS name of the ingress ALB (for greenfield service CNAME targets when tagging API data is not yet visible)."
  value       = data.aws_lb.load_balancer.dns_name
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
