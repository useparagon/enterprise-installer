resource "aws_route53_zone" "paragon" {
  name          = var.domain
  force_destroy = false
}

# Publish Route53 nameservers into a parent Cloudflare zone when credentials exist.
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
