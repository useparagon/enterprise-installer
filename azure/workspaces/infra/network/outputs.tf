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

output "nat_gateway_public_ip" {
  description = "Static public IP used for outbound SNAT from the private subnet."
  value       = azurerm_public_ip.nat.ip_address
}

output "private_subnet_nat_gateway_id" {
  description = "ID of the private subnet NAT gateway association. Used to order AKS outbound_type updates after the association exists."
  value       = azurerm_subnet_nat_gateway_association.private.id
}
