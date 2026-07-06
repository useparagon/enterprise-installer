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

  dynamic "assume_role" {
    for_each = var.aws_assume_role_arn != null && var.aws_assume_role_arn != "" ? [1] : []
    content {
      role_arn = var.aws_assume_role_arn
    }
  }

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
# Gated on argocd_enabled (or k8s_providers_enabled for destroy) so the providers are
# configured with empty credentials when GitOps is off, preventing client-go API
# discovery hangs against the EKS endpoint. The host must also be empty (not just
# the token) because client-go hangs on API discovery even with no auth token.
data "aws_eks_cluster_auth" "gitops" {
  count = local.k8s_providers_enabled ? 1 : 0
  name  = module.cluster.eks_cluster.name
}

locals {
  k8s_providers_enabled = var.argocd_enabled || var.k8s_providers_enabled
  k8s_host              = local.k8s_providers_enabled ? module.cluster.eks_cluster.cluster_endpoint : ""
  k8s_ca                = local.k8s_providers_enabled ? base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data) : ""
  k8s_token             = try(data.aws_eks_cluster_auth.gitops[0].token, "")
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = local.k8s_ca
  token                  = local.k8s_token
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = local.k8s_ca
    token                  = local.k8s_token
  }
}

# kubectl provider applies custom resources via server-side apply at apply-time and does
# NOT validate the GroupVersionKind at plan-time. This is required for CRs (ClusterSecretStore,
# ExternalSecret, ArgoCD Application) whose CRDs are installed earlier in the same apply.
provider "kubectl" {
  host                   = local.k8s_host
  cluster_ca_certificate = local.k8s_ca
  token                  = local.k8s_token
  load_config_file       = false
}
