# IRSA roles for External Secrets Operator, AWS Load Balancer Controller, and external-dns.

data "aws_iam_policy_document" "eso_assume" {
  count = local.enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.eso_namespace}:${local.eso_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  count = local.enabled ? 1 : 0

  name               = "${var.workspace}-eso"
  assume_role_policy = data.aws_iam_policy_document.eso_assume[0].json

  tags = {
    Name = "${var.workspace}-eso"
  }
}

data "aws_iam_policy_document" "eso_secrets" {
  count = local.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:BatchGetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = local.eso_secret_arns
  }
}

resource "aws_iam_role_policy" "eso_secrets" {
  count = local.enabled ? 1 : 0

  name   = "eso-secrets-access"
  role   = aws_iam_role.eso[0].id
  policy = data.aws_iam_policy_document.eso_secrets[0].json
}

data "aws_iam_policy_document" "lbc_assume" {
  count = local.gitops_ingress_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.lbc_namespace}:${local.lbc_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name               = "${var.workspace}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume[0].json

  tags = {
    Name = "${var.workspace}-aws-load-balancer-controller"
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name   = "${var.workspace}-aws-load-balancer-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  role       = aws_iam_role.aws_load_balancer_controller[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
}

data "aws_iam_policy_document" "external_dns_assume" {
  count = local.gitops_ingress_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.external_dns_namespace}:${local.external_dns_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name               = "${var.workspace}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume[0].json

  tags = {
    Name = "${var.workspace}-external-dns"
  }
}

data "aws_iam_policy_document" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [aws_route53_zone.paragon[0].arn]
  }

  statement {
    actions   = ["route53:ListTagsForResource"]
    resources = [aws_route53_zone.paragon[0].arn]
  }

  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name   = "external-dns"
  role   = aws_iam_role.external_dns[0].id
  policy = data.aws_iam_policy_document.external_dns[0].json
}
