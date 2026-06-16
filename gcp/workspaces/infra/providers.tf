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

# Kubernetes providers are only consumed when argocd_enabled creates the argocd module.
# Do not use try(..., "") fallbacks — empty host fails alekc/kubectl provider validation at plan.
provider "kubernetes" {
  host                   = module.cluster.kubernetes.host
  token                  = module.cluster.kubernetes.token
  cluster_ca_certificate = module.cluster.kubernetes.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.kubernetes.host
    token                  = module.cluster.kubernetes.token
    cluster_ca_certificate = module.cluster.kubernetes.cluster_ca_certificate
  }
}

provider "kubectl" {
  host                   = module.cluster.kubernetes.host
  token                  = module.cluster.kubernetes.token
  cluster_ca_certificate = module.cluster.kubernetes.cluster_ca_certificate
  load_config_file       = false
}

provider "time" {}
