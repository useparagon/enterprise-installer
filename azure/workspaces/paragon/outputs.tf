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
  description = "Active public front door FQDN (nginx, or AGC once agc_direct_routing is true)."
  value       = local.dns_ingress_target
}

output "agc_fqdn" {
  description = "AGC frontend FQDN for pre-cutover validation; CNAME hosts here on cutover (null when agc_enabled is false)."
  value       = local.agc_active ? module.agc.fqdn : null
}

output "agc_alb_id" {
  description = "Application Gateway for Containers resource ID (null when agc_enabled is false)."
  value       = local.agc_active ? module.agc.alb_id : null
}

output "nameservers" {
  description = "Azure DNS nameservers to delegate at the registrar (null when dns_provider is not azure_dns)."
  value       = local.azure_dns_enabled ? module.dns_zone.nameservers : null
}

output "agc_enabled" {
  description = "Whether Application Gateway for Containers is the public front door."
  value       = var.agc_enabled
}

output "agc_direct_routing" {
  description = "false = AGC forwards to ingress-nginx (transition); true = AGC routes directly to Services (nginx removed)."
  value       = var.agc_direct_routing
}
