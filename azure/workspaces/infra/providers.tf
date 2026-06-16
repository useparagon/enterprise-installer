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

# Kubernetes providers at the infra root (same layer as AWS EKS). OpenTofu does not reliably
# configure alekc/kubectl inside a nested argocd submodule when this workspace is pulled
# via git (enterprise-deployments stacks). Auth uses AKS admin kubeconfig, not IAM tokens.
#
# These providers are only consumed by the count-gated `argocd` module. On a fresh plan the
# AKS cluster does not exist yet, so its kube_config outputs are unknown. The hashicorp
# kubernetes/helm providers tolerate an unknown host, but alekc/kubectl errors at configure
# time ("no configuration has been provided"). So when ArgoCD is disabled we feed all three a
# static placeholder (they stay unused); when it is enabled the cluster already exists from a
# prior apply, so the real, known kube_config values are used.
locals {
  k8s_host = var.argocd_enabled ? module.cluster.kubernetes.host : "https://localhost"
  k8s_cert = var.argocd_enabled ? base64decode(module.cluster.kubernetes.client_certificate) : ""
  k8s_key  = var.argocd_enabled ? base64decode(module.cluster.kubernetes.client_key) : ""
  k8s_ca   = var.argocd_enabled ? base64decode(module.cluster.kubernetes.cluster_ca_certificate) : ""
}

provider "kubernetes" {
  host = local.k8s_host

  client_certificate     = local.k8s_cert
  client_key             = local.k8s_key
  cluster_ca_certificate = local.k8s_ca
}

provider "helm" {
  kubernetes {
    host = local.k8s_host

    client_certificate     = local.k8s_cert
    client_key             = local.k8s_key
    cluster_ca_certificate = local.k8s_ca
  }
}

provider "kubectl" {
  host = local.k8s_host

  client_certificate     = local.k8s_cert
  client_key             = local.k8s_key
  cluster_ca_certificate = local.k8s_ca
  load_config_file       = false
}

provider "random" {}
provider "time" {}
