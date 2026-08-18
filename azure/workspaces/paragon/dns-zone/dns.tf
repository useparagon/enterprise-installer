resource "azurerm_dns_zone" "paragon" {
  count = var.enabled ? 1 : 0

  name                = var.domain
  resource_group_name = var.resource_group_name
}

# CAA for Let's Encrypt so a restrictive parent CAA cannot block DNS-01 wildcards.
resource "azurerm_dns_caa_record" "letsencrypt" {
  count = var.enabled ? 1 : 0

  name                = "@"
  zone_name           = azurerm_dns_zone.paragon[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }

  record {
    flags = 0
    tag   = "issuewild"
    value = "letsencrypt.org"
  }
}

# Optional: publish Azure DNS nameservers into a parent Cloudflare zone
# (same pattern as aws/workspaces/paragon/alb/dns.tf).
resource "cloudflare_record" "nameserver" {
  # Azure assigns exactly 4 nameservers to every public DNS zone. length() of a zone that
  # does not exist yet is unknown at plan time and would break a greenfield apply.
  count = var.enabled && local.has_cloudflare_credentials ? 4 : 0

  content = azurerm_dns_zone.paragon[0].name_servers[count.index]
  name    = var.domain
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_zone_id
}

data "azurerm_client_config" "current" {}

# cert-manager azureDNS solver (and Terraform) need write access for _acme-challenge TXT records.
resource "azurerm_role_assignment" "dns_zone_contributor" {
  count = var.enabled ? 1 : 0

  scope                = azurerm_dns_zone.paragon[0].id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
