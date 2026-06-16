locals {
  enabled = var.argocd_enabled

  gitops_eso_namespace   = "external-secrets"
  gitops_eso_sa_name     = "external-secrets"
  gitops_ingress_enabled = local.enabled && trimspace(var.paragon_domain) != ""

  secrets_ready = local.enabled && (
    trimspace(var.paragon_domain) != "" &&
    var.docker_username != null && var.docker_username != "" &&
    var.docker_password != null && var.docker_password != ""
  )

  create_dns_zone = local.enabled && trimspace(var.paragon_domain) != ""

  cloudflare_enabled = local.create_dns_zone && (
    trimspace(var.cloudflare_api_token) != "" &&
    trimspace(var.cloudflare_zone_id) != "" &&
    var.cloudflare_api_token != "dummy-cloudflare-tokens-must-be-40-chars"
  )
}
