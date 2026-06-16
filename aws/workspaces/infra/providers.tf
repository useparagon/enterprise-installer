terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.42"
    }
  }
}

provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
  region     = var.aws_region
  default_tags {
    tags = local.default_tags
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Kubernetes API access for GitOps bootstrap (ArgoCD, ESO, platform manifests).
# Uses the same credentials as the AWS provider (Spacelift / assumed role) via EKS
# access entries on the cluster — not the bastion host.
data "aws_eks_cluster_auth" "gitops" {
  name = module.cluster.eks_cluster.name
}

provider "kubernetes" {
  host                   = module.cluster.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.gitops.token
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.gitops.token
  }
}

# kubectl provider applies custom resources via server-side apply at apply-time and does
# NOT validate the GroupVersionKind at plan-time. This is required for CRs (ClusterSecretStore,
# ExternalSecret, ArgoCD Application) whose CRDs are installed earlier in the same apply.
provider "kubectl" {
  host                   = module.cluster.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.gitops.token
  load_config_file       = false
}
