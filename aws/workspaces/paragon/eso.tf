locals {
  eso_namespace = "external-secrets"
  eso_sa_name   = "external-secrets"
  eso_secret_arns = compact([
    data.aws_secretsmanager_secret.env.arn,
    local.runtime_docker_cfg_sync_enabled ? data.aws_secretsmanager_secret.docker_cfg.arn : "",
    var.managed_sync_enabled ? data.aws_secretsmanager_secret.managed_sync[0].arn : "",
    data.aws_secretsmanager_secret.openobserve.arn,
  ])
}

data "aws_iam_policy_document" "eso_assume" {
  count = var.argocd_enabled ? 0 : 1

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.eso_namespace}:${local.eso_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  count = var.argocd_enabled ? 0 : 1

  name               = "${local.workspace}-eso"
  assume_role_policy = data.aws_iam_policy_document.eso_assume[0].json
}

data "aws_iam_policy_document" "eso_secrets" {
  count = var.argocd_enabled ? 0 : 1

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = local.eso_secret_arns
  }
}

resource "aws_iam_role_policy" "eso_secrets" {
  count = var.argocd_enabled ? 0 : 1

  name   = "eso-secrets-access"
  role   = aws_iam_role.eso[0].id
  policy = data.aws_iam_policy_document.eso_secrets[0].json
}

locals {
  eso_role_arn = var.argocd_enabled ? var.infra_eso_role_arn : aws_iam_role.eso[0].arn
}
