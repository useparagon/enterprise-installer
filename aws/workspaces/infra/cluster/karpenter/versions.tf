terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.0, < 3.0.0"
    }
  }
}
