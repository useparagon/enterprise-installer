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

# Kubernetes providers:
# - Spacelift injects backend-account env creds; the AWS provider assumes the customer role
#   in-process. Subprocess exec (aws eks get-token) only sees env creds, so pass --role-arn
#   to chain into the customer role. Static aws_eks_cluster_auth tokens also expire (~15m)
#   and break long applies.
# - Local runs with customer creds already in env: omit aws_assume_role_arn (or pass
#   customer_role_arn=) and use token auth from aws_eks_cluster_auth.
# - kubectl: lazy_load allows greenfield plans when the EKS endpoint is still unknown.
data "aws_eks_cluster_auth" "cluster" {
  count = local.k8s_use_token_auth ? 1 : 0
  name  = module.cluster.eks_cluster.name
}

locals {
  k8s_gitops_enabled = var.argocd_enabled || var.k8s_providers_enabled
  k8s_cluster_name   = module.cluster.eks_cluster.name
  k8s_host           = module.cluster.eks_cluster.cluster_endpoint
  k8s_ca             = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
  k8s_use_exec       = var.aws_assume_role_arn != null && var.aws_assume_role_arn != ""
  k8s_use_token_auth = !local.k8s_use_exec
  k8s_token          = local.k8s_use_token_auth ? data.aws_eks_cluster_auth.cluster[0].token : null
  k8s_exec_args = compact(flatten([
    ["eks", "get-token", "--cluster-name", local.k8s_cluster_name, "--region", var.aws_region],
    local.k8s_use_exec ? ["--role-arn", var.aws_assume_role_arn] : [],
  ]))
  kubectl_host = local.k8s_gitops_enabled ? local.k8s_host : "https://localhost"
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = local.k8s_ca
  token                  = local.k8s_token

  dynamic "exec" {
    for_each = local.k8s_use_exec ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.k8s_exec_args
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = local.k8s_ca
    token                  = local.k8s_token

    dynamic "exec" {
      for_each = local.k8s_use_exec ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = local.k8s_exec_args
      }
    }
  }
}

# kubectl provider applies custom resources via server-side apply at apply-time and does
# NOT validate the GroupVersionKind at plan-time. This is required for CRs (ClusterSecretStore,
# ExternalSecret, ArgoCD Application) whose CRDs are installed earlier in the same apply.
provider "kubectl" {
  host                   = local.kubectl_host
  cluster_ca_certificate = local.k8s_gitops_enabled ? local.k8s_ca : ""
  token                  = local.k8s_gitops_enabled && local.k8s_use_token_auth ? local.k8s_token : null
  load_config_file       = false
  lazy_load              = true

  dynamic "exec" {
    for_each = local.k8s_gitops_enabled && local.k8s_use_exec ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.k8s_exec_args
    }
  }
}
