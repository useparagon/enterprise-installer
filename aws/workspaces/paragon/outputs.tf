output "nameservers" {
  description = "The nameservers for the Route53 zone."
  value       = module.alb.nameservers
}

output "grafana_admin_email" {
  description = "Grafana admin login email."
  value       = var.monitors_enabled ? module.monitors[0].grafana_admin_email : null
  sensitive   = true
}

output "grafana_admin_password" {
  description = "Grafana admin login password."
  value       = var.monitors_enabled ? module.monitors[0].grafana_admin_password : null
  sensitive   = true
}

output "pgadmin_admin_email" {
  description = "PGAdmin admin login email."
  value       = var.monitors_enabled ? module.monitors[0].pgadmin_admin_email : null
  sensitive   = true
}

output "pgadmin_admin_password" {
  description = "PGAdmin admin login password."
  value       = var.monitors_enabled ? module.monitors[0].pgadmin_admin_password : null
  sensitive   = true
}

output "alb_arn" {
  description = "The ARN of the application load balancer."
  value       = module.alb.alb_arn
}

output "waf_web_acl_arn" {
  description = "ARN of the regional WAFv2 Web ACL when WAF is enabled, otherwise null."
  value       = local.waf_active ? module.waf[0].web_acl_arn : null
}

output "waf_logs_bucket" {
  description = "S3 bucket name for WAF traffic logs when WAF logging is enabled."
  value       = local.waf_active ? module.waf[0].waf_logs_bucket : null
}

output "uptime_webhook" {
  description = "Uptime webhook URL"
  value       = module.uptime.webhook
  sensitive   = true
}

output "openobserve_email" {
  value = module.helm.openobserve_email
}

output "openobserve_password" {
  value     = module.helm.openobserve_password
  sensitive = true
}
