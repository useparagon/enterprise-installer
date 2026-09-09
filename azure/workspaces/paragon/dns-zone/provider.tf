terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.42"
    }
  }
}

provider "cloudflare" {
  api_token = local.has_cloudflare_credentials ? var.cloudflare_api_token : "placeholder_0apiTokencloudflareonprem100"
}
