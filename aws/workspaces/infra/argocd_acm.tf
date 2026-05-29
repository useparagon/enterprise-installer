# ACM for Paragon ALB ingress when GitOps is enabled. Skipped when paragon_certificate_arn
# is set (e.g. cert already exists from a prior paragon workspace apply).
locals {
  paragon_domain_trimmed = var.paragon_domain != null ? trimspace(var.paragon_domain) : ""

  create_paragon_acm = (
    var.argocd_enabled &&
    local.paragon_domain_trimmed != "" &&
    trimspace(var.paragon_certificate_arn) == ""
  )

  paragon_certificate_arn = trimspace(var.paragon_certificate_arn) != "" ? trimspace(var.paragon_certificate_arn) : (
    local.create_paragon_acm ? module.paragon_acm[0].arn : ""
  )

  paragon_acm_cloudflare_enabled = (
    local.create_paragon_acm &&
    trimspace(var.cloudflare_api_token) != "" &&
    trimspace(var.cloudflare_tunnel_zone_id) != "" &&
    var.cloudflare_api_token != "dummy-cloudflare-tokens-must-be-40-chars"
  )
}

resource "aws_route53_zone" "paragon" {
  count = local.create_paragon_acm ? 1 : 0

  name          = local.paragon_domain_trimmed
  force_destroy = false
}

resource "aws_route53_record" "paragon_caa" {
  count = local.create_paragon_acm ? 1 : 0

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

resource "cloudflare_record" "paragon_nameserver" {
  count = local.paragon_acm_cloudflare_enabled ? length(aws_route53_zone.paragon[0].name_servers) : 0

  content = aws_route53_zone.paragon[0].name_servers[count.index]
  name    = local.paragon_domain_trimmed
  ttl     = 600
  type    = "NS"
  zone_id = var.cloudflare_tunnel_zone_id
}
