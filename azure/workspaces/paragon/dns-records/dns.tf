resource "azurerm_dns_a_record" "service" {
  for_each = var.enabled && local.is_ip ? var.public_services : {}

  name                = local.record_names[each.key]
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.record_ttl
  records             = [var.ingress_loadbalancer]
}

resource "azurerm_dns_cname_record" "service" {
  for_each = var.enabled && !local.is_ip ? var.public_services : {}

  name                = local.record_names[each.key]
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.record_ttl
  record              = var.ingress_loadbalancer
}
