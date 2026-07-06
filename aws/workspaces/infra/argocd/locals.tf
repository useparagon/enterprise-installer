locals {
  enabled = var.argocd_enabled

  eso_namespace = "external-secrets"
  eso_sa_name   = "external-secrets"

  gitops_ingress_enabled = local.enabled && trimspace(var.paragon_domain) != ""

  secret_prefix = "paragon/${var.workspace}"

  # Prefer concrete secret ARNs from the root secrets module; fall back to prefix wildcard.
  eso_secret_arns = length(var.secrets_manager_secret_arns) > 0 ? var.secrets_manager_secret_arns : [
    "arn:aws:secretsmanager:${var.aws_region}:*:secret:${local.secret_prefix}/*",
  ]

  create_dns_zone = local.enabled && trimspace(var.paragon_domain) != ""

  create_paragon_acm = (
    local.create_dns_zone &&
    trimspace(var.paragon_certificate_arn) == ""
  )

  paragon_certificate_arn_resolved = trimspace(var.paragon_certificate_arn) != "" ? trimspace(var.paragon_certificate_arn) : (
    local.create_paragon_acm ? module.paragon_acm[0].arn : ""
  )

  cloudflare_enabled = local.create_dns_zone && (
    trimspace(var.cloudflare_api_token) != "" &&
    trimspace(var.cloudflare_zone_id) != "" &&
    var.cloudflare_api_token != "dummy-cloudflare-tokens-must-be-40-chars"
  )

  gitops_alb_ingress_class_exists = local.enabled && var.gitops_alb_ingressclass_exists

  lbc_namespace = "kube-system"
  lbc_sa_name   = "aws-load-balancer-controller"

  external_dns_namespace = "external-dns"
  external_dns_sa_name   = "external-dns"
}
