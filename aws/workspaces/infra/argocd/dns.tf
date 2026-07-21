# Route 53 zone, ACM, and Cloudflare NS delegation for Paragon GitOps ingress.

resource "aws_route53_zone" "paragon" {
  count = local.create_dns_zone ? 1 : 0

  name          = trimspace(var.paragon_domain)
  force_destroy = false

  tags = {
    Name = trimspace(var.paragon_domain)
  }
}

resource "aws_route53_record" "paragon_caa" {
  count = local.create_dns_zone ? 1 : 0

  # Brownfield cutovers often already have this CAA from the legacy paragon ALB module.
  allow_overwrite = true
  name            = trimspace(var.paragon_domain)
  records         = ["0 issue \"amazon.com\""]
  ttl             = 300
  type            = "CAA"
  zone_id         = aws_route53_zone.paragon[0].zone_id
}

module "paragon_acm" {
  count = local.create_paragon_acm ? 1 : 0

  source  = "cloudposse/acm-request-certificate/aws"
  version = "0.17.0"

  domain_name                       = trimspace(var.paragon_domain)
  process_domain_validation_options = true
  ttl                               = "300"
  subject_alternative_names         = ["*.${trimspace(var.paragon_domain)}"]
  zone_id                           = aws_route53_zone.paragon[0].zone_id
}

resource "cloudflare_record" "paragon_nameserver" {
  count = local.cloudflare_enabled ? 4 : 0

  content = aws_route53_zone.paragon[0].name_servers[count.index]
  name    = trimspace(var.paragon_domain)
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_zone_id
}
