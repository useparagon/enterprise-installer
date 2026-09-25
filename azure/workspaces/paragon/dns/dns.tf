data "cloudflare_zone" "zone" {
  count = var.enabled ? 1 : 0

  zone_id = var.cloudflare_zone_id
}

locals {
  is_ip = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.ingress_loadbalancer))
}

resource "cloudflare_record" "cname" {
  for_each = var.enabled ? var.public_services : {}

  # Path-routed public URLs belong to the customer's reverse proxy. DNS keeps
  # the Paragon-domain origin hostname that proxy targets.
  name = replace(
    coalesce(
      try(each.value.origin_host, null),
      replace(replace(each.value.public_url, "https://", ""), "http://", "")
    ),
    ".${data.cloudflare_zone.zone[0].name}",
    ""
  )

  content = var.ingress_loadbalancer
  ttl     = var.ttl
  type    = local.is_ip ? "A" : "CNAME"
  zone_id = var.cloudflare_zone_id
}
