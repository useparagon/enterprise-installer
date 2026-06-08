# Route 53 zone, ACM, and Cloudflare NS delegation for Paragon GitOps ingress.
locals {
  create_paragon_zone = (
    var.argocd_enabled &&
    local.paragon_domain_trimmed != ""
  )

  create_paragon_acm = (
    local.create_paragon_zone &&
    trimspace(var.paragon_certificate_arn) == ""
  )

  paragon_certificate_arn = trimspace(var.paragon_certificate_arn) != "" ? trimspace(var.paragon_certificate_arn) : (
    local.create_paragon_acm ? module.paragon_acm[0].arn : ""
  )

  paragon_route53_cloudflare_enabled = (
    local.create_paragon_zone &&
    trimspace(var.cloudflare_api_token) != "" &&
    trimspace(var.cloudflare_tunnel_zone_id) != "" &&
    var.cloudflare_api_token != "dummy-cloudflare-tokens-must-be-40-chars"
  )
}

resource "aws_route53_zone" "paragon" {
  count = local.create_paragon_zone ? 1 : 0

  name          = local.paragon_domain_trimmed
  force_destroy = false

  tags = merge(local.default_tags, {
    Name = local.paragon_domain_trimmed
  })
}

resource "aws_route53_record" "paragon_caa" {
  count = local.create_paragon_zone ? 1 : 0

  name    = local.paragon_domain_trimmed
  records = ["0 issue \"amazon.com\""]
  ttl     = 300
  type    = "CAA"
  zone_id = aws_route53_zone.paragon[0].zone_id
}

module "paragon_acm" {
  count = local.create_paragon_acm ? 1 : 0

  source  = "cloudposse/acm-request-certificate/aws"
  version = "0.17.0"

  domain_name                       = local.paragon_domain_trimmed
  process_domain_validation_options = true
  ttl                               = "300"
  subject_alternative_names         = ["*.${local.paragon_domain_trimmed}"]
  zone_id                           = aws_route53_zone.paragon[0].zone_id
}

# Delegate Route 53 NS to Cloudflare (same pattern as paragon workspace alb/dns.tf).
# count must be plan-time constant; AWS hosted zones always get four name servers.
resource "cloudflare_record" "paragon_nameserver" {
  count = local.paragon_route53_cloudflare_enabled ? 4 : 0

  content = aws_route53_zone.paragon[0].name_servers[count.index]
  name    = local.paragon_domain_trimmed
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_tunnel_zone_id
}
