terraform {
  required_providers {
    hoop = {
      source  = "hoophq/hoop"
      version = ">= 0.0.19"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0, < 3.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}
