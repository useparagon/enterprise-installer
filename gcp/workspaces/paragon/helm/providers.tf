terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.12.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.17.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

provider "helm" {
  # Connect Gateway enforces a per-minute request quota. Helm discovery creates
  # a new client for each release, so cap each client's initial request burst.
  burst_limit = 20

  kubernetes {
    host  = local.cluster.host
    token = local.cluster.token
  }
}

provider "kubernetes" {
  host  = local.cluster.host
  token = local.cluster.token
}

provider "kubectl" {
  host             = local.cluster.host
  token            = local.cluster.token
  load_config_file = false
}
