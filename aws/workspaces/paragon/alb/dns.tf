resource "aws_route53_zone" "paragon" {
  name          = var.domain
  force_destroy = false
}

resource "aws_route53_record" "microservice" {
  for_each = merge(var.public_microservices, var.public_monitors)

  zone_id = aws_route53_zone.paragon.zone_id
  # Path-routed public hosts belong to the external reverse proxy. Keep the
  # per-service Paragon-domain CNAME as the TLS-valid origin that proxy can target.
  name = (
    var.path_based_routing_enabled &&
    contains(keys(var.public_microservices), each.key) &&
    try(each.value.path_prefix, "") != ""
    ) ? each.key : replace(
    replace(
      replace(each.value.public_url, var.domain, ""),
      "https://",
      ""
    ),
    "http://",
    ""
  )
  type    = "CNAME"
  ttl     = 300
  records = [data.aws_lb.load_balancer.dns_name]
}

# adding the dns record entry to cloudfare if creds exist
resource "cloudflare_record" "nameserver" {
  # Route53 public hosted zones always have exactly 4 nameservers. length() of a
  # zone that does not exist yet is unknown at plan time and breaks a greenfield apply.
  count = local.has_cloudflare_credentials ? 4 : 0

  content = aws_route53_zone.paragon.name_servers[count.index]
  name    = var.domain
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_zone_id
}
