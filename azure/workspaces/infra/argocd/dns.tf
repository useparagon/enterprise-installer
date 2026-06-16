# Azure DNS zone for paragon_domain + Cloudflare NS delegation.

resource "azurerm_dns_zone" "paragon" {
  count = local.create_dns_zone ? 1 : 0

  name                = trimspace(var.paragon_domain)
  resource_group_name = var.azure_resource_group_name
}

resource "cloudflare_record" "paragon_nameserver" {
  count = local.cloudflare_enabled ? 4 : 0

  content = tolist(azurerm_dns_zone.paragon[0].name_servers)[count.index]
  name    = trimspace(var.paragon_domain)
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_zone_id
}
