output "nameservers" {
  description = "The nameservers for the Route53 zone."
  value       = aws_route53_zone.paragon.name_servers
}

output "certificate" {
  description = "The ARN of the ACM certificate."
  value       = var.certificate == null ? module.acm_request_certificate[0].arn : var.certificate
}

output "alb_arn" {
  description = "The ARN of the application load balancer."
  value       = data.aws_lb.load_balancer.arn
}

output "backend_security_group_id" {
  description = "Security group used as the AWS Load Balancer Controller backend SG and as the source of worker target-port safeguards."
  value       = aws_security_group.alb_backend.id
}
