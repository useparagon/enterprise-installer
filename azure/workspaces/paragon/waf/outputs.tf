output "policy_id" {
  description = "Azure WAF policy resource ID."
  value       = azurerm_web_application_firewall_policy.this.id
}

output "policy_name" {
  description = "Azure WAF policy name."
  value       = azurerm_web_application_firewall_policy.this.name
}
