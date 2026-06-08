# Cloud DNS zone for paragon_domain + Cloudflare NS delegation.
# Created inside the module so DNS infrastructure is fully encapsulated
# behind the argocd_enabled feature flag.

locals {
  create_dns_zone = trimspace(var.paragon_domain) != ""

  cloudflare_enabled = (
    local.create_dns_zone &&
    trimspace(var.cloudflare_api_token) != "" &&
    var.cloudflare_api_token != "dummy-cloudflare-tokens-must-be-40-chars"
  )
}

resource "google_dns_managed_zone" "paragon" {
  count = local.create_dns_zone ? 1 : 0

  name        = replace("${var.workspace}-zone", "/[^a-z0-9-]/", "-")
  dns_name    = "${trimspace(var.paragon_domain)}."
  project     = var.gcp_project_id
  description = "Paragon domain zone for ${var.workspace}"

  labels = var.labels
}

resource "cloudflare_record" "paragon_nameserver" {
  count = local.cloudflare_enabled ? 4 : 0

  zone_id = var.cloudflare_zone_id
  name    = trimspace(var.paragon_domain)
  type    = "NS"
  value   = google_dns_managed_zone.paragon[0].name_servers[count.index]
  ttl     = 86400
}
