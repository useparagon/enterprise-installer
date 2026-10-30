data "aws_caller_identity" "current" {}

data "aws_iam_role" "bastion" {
  name = local.bastion_name

  depends_on = [
    module.bastion
  ]
}

# infrastructure read only role for bastion
data "aws_iam_policy_document" "bastion_infra_read_only" {
  statement {
    actions = [
      "acm:Describe*",
      "acm:Get*",
      "acm:List*",
      "autoscaling:Describe*",
      "autoscaling:Get*",
      "cloudformation:Describe*",
      "cloudformation:Get*",
      "cloudformation:List*",
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "ec2:Describe*",
      "ec2:Get*",
      "ecr:BatchGet*",
      "ecr:Describe*",
      "ecr:Get*",
      "ecr:List*",
      "eks:Describe*",
      "eks:List*",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:Get*",
      "elasticloadbalancing:List*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "s3:ListAllMyBuckets",
      "ssm:Get*",
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "bastion_infra_read_only" {
  name   = "${local.bastion_name}-infra-read-only"
  policy = data.aws_iam_policy_document.bastion_infra_read_only.json

  tags = {
    Name = "${local.bastion_name}-infra-read-only"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_infra_read_only" {
  policy_arn = aws_iam_policy.bastion_infra_read_only.arn
  role       = data.aws_iam_role.bastion.name
}

# allow bastion to assume role
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    resources = [
      data.aws_iam_role.bastion.arn
    ]
  }
}

resource "aws_iam_policy" "assume_role" {
  name   = "${local.bastion_name}-assume-role"
  policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${local.bastion_name}-assume-role"
  }
}

resource "aws_iam_role_policy_attachment" "assume_role" {
  policy_arn = aws_iam_policy.assume_role.arn
  role       = data.aws_iam_role.bastion.name
}

# Scoped pre-destroy cleanup to avoid orphaned ingress ALBs and versioned workspace buckets
data "aws_iam_policy_document" "bastion_cleanup" {
  statement {
    sid = "ElbDeleteClusterTagged"
    actions = [
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
    ]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:ResourceTag/elbv2.k8s.aws/cluster"
      values   = [var.cluster_name]
    }
  }

  statement {
    sid = "ElbDeleteByWorkspaceName"
    actions = [
      "elasticloadbalancing:DeleteLoadBalancer",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:elasticloadbalancing:${var.aws_region}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/${var.workspace}/*",
      "arn:aws:elasticloadbalancing:${var.aws_region}:${data.aws_caller_identity.current.account_id}:loadbalancer/net/${var.workspace}/*",
    ]
  }

  statement {
    sid = "WorkspaceS3EmptyForDestroy"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${var.workspace}*",
      "arn:aws:s3:::${var.workspace}*/*",
    ]
  }
}

resource "aws_iam_policy" "bastion_cleanup" {
  name   = "${local.bastion_name}-cleanup"
  policy = data.aws_iam_policy_document.bastion_cleanup.json

  tags = {
    Name = "${local.bastion_name}-cleanup"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_cleanup" {
  policy_arn = aws_iam_policy.bastion_cleanup.arn
  role       = data.aws_iam_role.bastion.name
}
