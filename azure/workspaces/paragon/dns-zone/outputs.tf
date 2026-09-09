output "nameservers" {
  description = "Azure DNS nameservers to delegate at the registrar."
  value       = var.enabled ? azurerm_dns_zone.paragon[0].name_servers : []
}

output "zone_id" {
  description = "Azure DNS zone ID."
  value       = var.enabled ? azurerm_dns_zone.paragon[0].id : null
}

output "zone_name" {
  description = "Azure DNS zone name."
  value       = var.enabled ? azurerm_dns_zone.paragon[0].name : null
}

output "resource_group_name" {
  description = "Resource group that owns the DNS zone."
  value       = var.enabled ? var.resource_group_name : null
}
