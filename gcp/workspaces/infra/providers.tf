terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
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
  }
}

provider "google" {
  credentials    = var.gcp_assume_role ? null : local.gcp_creds
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}

provider "google-beta" {
  credentials    = var.gcp_assume_role ? null : local.gcp_creds
  default_labels = local.default_labels
  project        = local.gcp_project_id
  region         = var.region
  zone           = var.region_zone
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Kubernetes providers at the infra root. Only consumed by the count-gated argocd
# module; on a fresh plan the GKE cluster does not exist yet so its outputs are
# unknown. alekc/kubectl errors at configure time on an unknown host, so feed all
# three a static placeholder when ArgoCD is disabled (they stay unused); use the
# real cluster values when enabled (the cluster exists from a prior apply).
locals {
  k8s_host  = var.argocd_enabled ? module.cluster.kubernetes.host : "https://localhost"
  k8s_token = var.argocd_enabled ? module.cluster.kubernetes.token : ""
  k8s_ca    = var.argocd_enabled ? module.cluster.kubernetes.cluster_ca_certificate : ""
}

provider "kubernetes" {
  host                   = local.k8s_host
  token                  = local.k8s_token
  cluster_ca_certificate = local.k8s_ca
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    token                  = local.k8s_token
    cluster_ca_certificate = local.k8s_ca
  }
}

provider "kubectl" {
  host                   = local.k8s_host
  token                  = local.k8s_token
  cluster_ca_certificate = local.k8s_ca
  load_config_file       = false
}
