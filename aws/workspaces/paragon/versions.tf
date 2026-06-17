# Root required_providers so `provider "hoop"` resolves to hoophq/hoop (not hashicorp/hoop).
# Child modules (alb, helm, hoop, uptime) declare additional providers.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0, ~> 5.70"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.12.0"
    }
    hoop = {
      source  = "hoophq/hoop"
      version = ">= 0.0.19"
    }
  }
}
