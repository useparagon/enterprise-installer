data "aws_iam_policy_document" "controller_assume" {
  count = var.create ? 1 : 0

  statement {
    sid = "PodIdentity"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "controller" {
  count = var.create ? 1 : 0

  name               = var.controller_role_name
  assume_role_policy = data.aws_iam_policy_document.controller_assume[0].json
  tags               = var.tags
}

resource "aws_iam_policy" "controller_ec2" {
  count = var.create ? 1 : 0

  name_prefix = "KarpenterCtrlEC2-${var.cluster_name}-"
  description = "Karpenter controller EC2 policy for cluster ${var.cluster_name}"
  policy      = data.aws_iam_policy_document.karpenter_controller_ec2[0].json
  tags        = var.tags
}

resource "aws_iam_policy" "controller_services" {
  count = var.create ? 1 : 0

  name_prefix = "KarpenterCtrlSvc-${var.cluster_name}-"
  description = "Karpenter controller SSM/SQS/IAM/EKS/KMS policy for cluster ${var.cluster_name}"
  policy      = data.aws_iam_policy_document.karpenter_controller_services[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "controller_ec2" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.controller[0].name
  policy_arn = aws_iam_policy.controller_ec2[0].arn
}

resource "aws_iam_role_policy_attachment" "controller_services" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.controller[0].name
  policy_arn = aws_iam_policy.controller_services[0].arn
}

data "aws_iam_policy_document" "node_assume" {
  count = var.create ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [local.ec2_sp_name]
    }
  }
}

resource "aws_iam_role" "node" {
  count = var.create ? 1 : 0

  name               = var.node_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node_eks_managed" {
  for_each = var.create ? merge(
    {
      # Match terraform-aws-modules/eks v21 eks-managed-node-group default node role policies.
      AmazonEKSWorkerNodePolicy          = "${local.node_policy_prefix}/AmazonEKSWorkerNodePolicy"
      AmazonEC2ContainerRegistryReadOnly = "${local.node_policy_prefix}/AmazonEC2ContainerRegistryReadOnly"
    },
    local.ipv4_cni_policy,
    local.ipv6_cni_policy
  ) : {}

  role       = aws_iam_role.node[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "node_additional" {
  for_each = var.create ? var.node_iam_role_additional_policies : {}

  role       = aws_iam_role.node[0].name
  policy_arn = each.value
}

resource "aws_eks_access_entry" "karpenter_node" {
  count = var.create ? 1 : 0

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.node[0].arn
  type          = "EC2_LINUX"
  tags          = var.tags
}

resource "aws_eks_pod_identity_association" "karpenter" {
  count = var.create ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.karpenter_namespace
  service_account = var.karpenter_service_account
  role_arn        = aws_iam_role.controller[0].arn
  tags            = var.tags
}
