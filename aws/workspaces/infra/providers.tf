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
# - kubernetes/helm: always target the EKS API (cluster-autoscaler Helm runs when argocd is off).
#   Use aws eks get-token exec auth so apply works once the cluster exists without a plan-time
#   aws_eks_cluster_auth read against a not-yet-created cluster.
# - kubectl: only used by the count-gated argocd module. alekc/kubectl rejects an empty host at
#   configure time, so use a localhost placeholder when GitOps is off (providers stay unused).
locals {
  k8s_gitops_enabled = var.argocd_enabled || var.k8s_providers_enabled
  k8s_cluster_name   = module.cluster.eks_cluster.name
  k8s_host           = module.cluster.eks_cluster.cluster_endpoint
  k8s_ca             = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
  k8s_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.k8s_cluster_name, "--region", var.aws_region]
  }
  kubectl_host = local.k8s_gitops_enabled ? local.k8s_host : "https://localhost"
}

provider "kubernetes" {
  host                   = local.k8s_host
  cluster_ca_certificate = local.k8s_ca

  exec {
    api_version = local.k8s_exec.api_version
    command     = local.k8s_exec.command
    args        = local.k8s_exec.args
  }
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_host
    cluster_ca_certificate = local.k8s_ca

    exec {
      api_version = local.k8s_exec.api_version
      command     = local.k8s_exec.command
      args        = local.k8s_exec.args
    }
  }
}

# kubectl provider applies custom resources via server-side apply at apply-time and does
# NOT validate the GroupVersionKind at plan-time. This is required for CRs (ClusterSecretStore,
# ExternalSecret, ArgoCD Application) whose CRDs are installed earlier in the same apply.
provider "kubectl" {
  host                   = local.kubectl_host
  cluster_ca_certificate = local.k8s_gitops_enabled ? local.k8s_ca : ""
  load_config_file       = false

  dynamic "exec" {
    for_each = local.k8s_gitops_enabled ? [1] : []
    content {
      api_version = local.k8s_exec.api_version
      command     = local.k8s_exec.command
      args        = local.k8s_exec.args
    }
  }
}
