provider "cloudflare" {
  api_token = var.cloudflare_api_token == "dummy-cloudflare-tokens-must-be-40-chars" ? null : var.cloudflare_api_token
}
