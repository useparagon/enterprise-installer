resource "azurerm_private_dns_zone" "redis" {
  count = length(local.redis_instances) > 0 ? 1 : 0

  name                = "privatelink.redis.azure.net"
  resource_group_name = var.resource_group.name
  tags                = merge(var.tags, { Name = "${var.workspace}-redis-managed-dns" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  count = length(local.redis_instances) > 0 ? 1 : 0

  name                  = "${var.workspace}-redis-managed-dns-link"
  resource_group_name   = var.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.redis[0].name
  virtual_network_id    = var.virtual_network.id
  tags                  = merge(var.tags, { Name = "${var.workspace}-redis-managed-dns-link" })
}

resource "azurerm_private_endpoint" "redis" {
  for_each = local.redis_instances

  name                = "${var.workspace}-${each.key}-redis-managed-pe"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  subnet_id           = var.private_subnet.id

  private_service_connection {
    name                           = "${var.workspace}-${each.key}-redis-managed-connection"
    private_connection_resource_id = azurerm_managed_redis.redis[each.key].id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-managed-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis[0].id]
  }

  tags = merge(var.tags, { Name = "${var.workspace}-${each.key}-redis-managed-pe" })

  depends_on = [azurerm_private_dns_zone_virtual_network_link.redis]
}
