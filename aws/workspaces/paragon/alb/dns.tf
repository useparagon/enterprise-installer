data "aws_lb" "load_balancer" {
  name = var.workspace

  # Gate is created after the Helm releases that provision the ALB, then stays
  # unchanged. Depending on the helm_release objects themselves defers this
  # lookup on every chart/values change and makes Route53 records look like drift.
  depends_on = [var.alb_lookup_gate]
}

resource "aws_route53_zone" "paragon" {
  name          = var.domain
  force_destroy = false
}

resource "aws_route53_record" "microservice" {
  for_each = merge(var.public_microservices, var.public_monitors)

  zone_id = aws_route53_zone.paragon.zone_id
  name = replace(
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
  count = local.has_cloudflare_credentials ? length(aws_route53_zone.paragon.name_servers) : 0

  content = aws_route53_zone.paragon.name_servers[count.index]
  name    = var.domain
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_zone_id
}
