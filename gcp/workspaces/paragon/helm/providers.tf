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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.12.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}


provider "helm" {
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
