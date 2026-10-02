# Lookup by stable ALB name only — do not depends_on Helm releases here. That
# defers dns_name to apply time whenever ingress/on-prem chart versions change,
# which makes every aws_route53_record.microservice look like drift (records ->
# known after apply). Same class of issue as alb/security_groups.tf.
data "aws_lb" "load_balancer" {
  name = var.workspace
}

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
