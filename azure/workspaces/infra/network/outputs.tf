output "resource_group" {
  value = azurerm_resource_group.main
}

output "virtual_network" {
  value = azurerm_virtual_network.main
}

output "public_subnet" {
  value = azurerm_subnet.public
}

output "private_subnet" {
  value = azurerm_subnet.private
}

output "postgres_subnet" {
  value = azurerm_subnet.postgres
}

output "redis_subnet" {
  value = azurerm_subnet.redis
}

output "agc_subnet" {
  description = "Dedicated AGC association subnet (null when agc_subnet_enabled is false)."
  value       = var.agc_subnet_enabled ? azurerm_subnet.agc[0] : null
}

output "agc_nsg_id" {
  description = "NSG attached to the AGC association subnet (null when disabled)."
  value       = var.agc_subnet_enabled ? azurerm_network_security_group.agc[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Static public IP used for outbound SNAT from the private subnet."
  value       = azurerm_public_ip.nat.ip_address
}

output "private_subnet_nat_gateway_id" {
  description = "ID of the private subnet NAT gateway association. Used to order AKS outbound_type updates after the association exists."
  value       = azurerm_subnet_nat_gateway_association.private.id
}

output "aks_nsg_id" {
  description = "NSG attached to the public and private (AKS) subnets."
  value       = azurerm_network_security_group.aks.id
}

output "default_closed_nsg_id" {
  description = "NSG attached to the redis subnet (baseline + Premium Redis VNet ports)."
  value       = azurerm_network_security_group.default_closed.id
}
