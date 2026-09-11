provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  # SP cannot register namespaces. setup-roles.sh registers them, including
  # Microsoft.ServiceNetworking for AGC subnet delegation.
  resource_provider_registrations = "none"
  features {}
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
