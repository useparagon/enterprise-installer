terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}


provider "cloudflare" {
  api_token = var.cloudflare_dns_api_token != null ? var.cloudflare_dns_api_token : "placeholder_0apiTokencloudflareonprem100"
}
