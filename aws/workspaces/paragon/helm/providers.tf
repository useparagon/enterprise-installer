terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.12.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

# Refresh EKS tokens via exec so long Helm rollouts do not fail when a static
# STS token expires mid-apply (~15 minutes).
locals {
  eks_get_token_args = concat(
    [
      "eks", "get-token",
      "--cluster-name", var.cluster_name,
      "--region", var.aws_region,
    ],
    var.aws_assume_role_arn != null && var.aws_assume_role_arn != "" ? ["--role-arn", var.aws_assume_role_arn] : [],
  )

  eks_exec_env = merge(
    { AWS_REGION = var.aws_region },
    var.aws_access_key_id != null && var.aws_access_key_id != "" ? {
      AWS_ACCESS_KEY_ID     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    } : {},
    var.aws_session_token != null && var.aws_session_token != "" ? {
      AWS_SESSION_TOKEN = var.aws_session_token
    } : {},
  )
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.eks_get_token_args
      env         = local.eks_exec_env
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.eks_get_token_args
    env         = local.eks_exec_env
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.eks_get_token_args
    env         = local.eks_exec_env
  }
}
