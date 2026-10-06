# Required so Terraform uses hoophq/hoop instead of default hashicorp/hoop (which does not exist).
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    hoop = {
      source  = "hoophq/hoop"
      version = "0.0.21"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

