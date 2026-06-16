terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.42"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  features {}
}

provider "azuread" {
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id     = var.azure_tenant_id
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token == "dummy-cloudflare-tokens-must-be-40-chars" ? null : var.cloudflare_api_token
}

# Kubernetes providers are only consumed when argocd_enabled creates the argocd module.
# Do not use try(..., "") fallbacks — empty host fails alekc/kubectl provider validation at plan.
provider "kubernetes" {
  host = module.cluster.kubernetes.host

  client_certificate     = base64decode(module.cluster.kubernetes.client_certificate)
  client_key             = base64decode(module.cluster.kubernetes.client_key)
  cluster_ca_certificate = base64decode(module.cluster.kubernetes.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = module.cluster.kubernetes.host

    client_certificate     = base64decode(module.cluster.kubernetes.client_certificate)
    client_key             = base64decode(module.cluster.kubernetes.client_key)
    cluster_ca_certificate = base64decode(module.cluster.kubernetes.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host = module.cluster.kubernetes.host

  client_certificate     = base64decode(module.cluster.kubernetes.client_certificate)
  client_key             = base64decode(module.cluster.kubernetes.client_key)
  cluster_ca_certificate = base64decode(module.cluster.kubernetes.cluster_ca_certificate)
  load_config_file       = false
}
