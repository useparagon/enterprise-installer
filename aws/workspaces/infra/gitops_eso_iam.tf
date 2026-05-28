# ESO IAM lives at the infra root so eks-blueprints-addons can install the operator
# (with IRSA) before the argocd bootstrap module applies ClusterSecretStore manifests.

locals {
  gitops_eso_namespace = "external-secrets"
  gitops_eso_sa_name   = "external-secrets"
}

data "aws_iam_policy_document" "gitops_eso_assume" {
  count = var.argocd_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.cluster.eks_cluster.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.cluster.eks_cluster.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.gitops_eso_namespace}:${local.gitops_eso_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.cluster.eks_cluster.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gitops_eso" {
  count = var.argocd_enabled ? 1 : 0

  name               = "${local.workspace}-eso"
  assume_role_policy = data.aws_iam_policy_document.gitops_eso_assume[0].json

  tags = {
    Name = "${local.workspace}-eso"
  }
}

data "aws_iam_policy_document" "gitops_eso_secrets" {
  count = var.argocd_enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = var.argocd_enabled && local.argocd_secrets_ready ? module.secrets[0].secret_arns : ["arn:aws:secretsmanager:${var.aws_region}:*:secret:paragon/${local.workspace}/*"]
  }
}

resource "aws_iam_role_policy" "gitops_eso" {
  count = var.argocd_enabled ? 1 : 0

  name   = "eso-secrets-access"
  role   = aws_iam_role.gitops_eso[0].id
  policy = data.aws_iam_policy_document.gitops_eso_secrets[0].json
}
