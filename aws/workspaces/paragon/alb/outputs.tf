output "nameservers" {
  description = "The nameservers for the Route53 zone."
  value       = aws_route53_zone.paragon.name_servers
}

output "route53_zone_id" {
  description = "Route 53 hosted zone for the Paragon deployment domain."
  value       = aws_route53_zone.paragon.zone_id
}

output "certificate" {
  description = "The ARN of the ACM certificate."
  value       = var.certificate == null ? module.acm_request_certificate[0].arn : var.certificate
}

output "backend_security_group_id" {
  description = "Security group used as the AWS Load Balancer Controller backend SG and as the source of worker target-port safeguards."
  value       = aws_security_group.alb_backend.id
}
