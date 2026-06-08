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
