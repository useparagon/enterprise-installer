resource "aws_route53_zone" "paragon" {
  name          = var.domain
  force_destroy = false
}

# adding the dns record entry to cloudfare if creds exist
resource "cloudflare_record" "nameserver" {
  count = local.has_cloudflare_credentials ? length(aws_route53_zone.paragon.name_servers) : 0

  content = aws_route53_zone.paragon.name_servers[count.index]
  name    = var.domain
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_zone_id
}
