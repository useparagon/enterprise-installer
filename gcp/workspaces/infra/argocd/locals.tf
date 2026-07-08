locals {
  enabled = var.argocd_enabled

  gitops_eso_namespace   = "external-secrets"
  gitops_eso_sa_name     = "external-secrets"
  gitops_ingress_enabled = local.enabled && trimspace(var.paragon_domain) != ""

  gitops_eso_account_id          = replace(substr("${var.workspace}-eso", 0, 30), "/-$/", "")
  gitops_external_dns_account_id = replace(substr("${var.workspace}-edns", 0, 30), "/-$/", "")

  secrets_ready = local.enabled && (
    trimspace(var.paragon_domain) != "" &&
    var.docker_username != null && var.docker_username != "" &&
    var.docker_password != null && var.docker_password != ""
  )

  create_dns_zone = local.enabled && trimspace(var.paragon_domain) != ""

  cloudflare_enabled = local.create_dns_zone && (
    trimspace(var.cloudflare_api_token) != "" &&
    var.cloudflare_api_token != "dummy-cloudflare-tokens-must-be-40-chars"
  )
}
