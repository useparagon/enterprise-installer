output "fqdn" {
  description = "ALB-managed AGC frontend FQDN from the Gateway status. Point DNS (CNAME) here on cutover (null until the controller programs the Gateway)."
  value       = try(data.kubernetes_resource.gateway[0].object.status.addresses[0].value, null)
}

output "alb_id" {
  description = "Application Gateway for Containers resource ID."
  value       = one(azurerm_application_load_balancer.this[*].id)
}

output "identity_client_id" {
  description = "Client ID of the ALB controller user-assigned identity."
  value       = one(azurerm_user_assigned_identity.alb[*].client_id)
}

output "identity_principal_id" {
  description = "Principal ID of the ALB controller user-assigned identity."
  value       = one(azurerm_user_assigned_identity.alb[*].principal_id)
}
