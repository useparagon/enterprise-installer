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

# Refresh EKS tokens via exec so long Helm rollouts do not fail when the
# 15-minute STS token from data.aws_eks_cluster_auth expires mid-apply.
locals {
  eks_get_token_args = concat(
    [
      "eks", "get-token",
      "--cluster-name", local.cluster_name,
      "--region", var.aws_region,
    ],
    var.aws_assume_role_arn != null && var.aws_assume_role_arn != "" ? ["--role-arn", var.aws_assume_role_arn] : [],
  )

  # Pass static keys into the exec subprocess when set; otherwise aws CLI uses
  # ambient credentials (Spacelift AWS integration / instance profile / env).
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

provider "hoop" {
  api_url = var.hoop_api_url
  api_key = coalesce(var.hoop_api_key, "dummy-token")
}
