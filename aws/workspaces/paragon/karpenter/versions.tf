terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0, < 3.0.0"
    }
  }
}
