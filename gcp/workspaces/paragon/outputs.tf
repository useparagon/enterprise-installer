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

output "uptime_webhook" {
  description = "Uptime webhook URL"
  value       = module.uptime.webhook
  sensitive   = true
}

output "load_balancer" {
  description = "Location of the load balancer"
  value       = module.helm.load_balancer
}

output "waf_security_policy_name" {
  description = "Name of the Cloud Armor security policy when WAF is enabled, otherwise null."
  value       = local.waf_active ? module.waf[0].security_policy_name : null
}

output "waf_rule_count" {
  description = "Number of rules in the Cloud Armor policy when WAF is enabled, otherwise null. The default quota is 200 rules per policy."
  value       = local.waf_active ? module.waf[0].rule_count : null
}
