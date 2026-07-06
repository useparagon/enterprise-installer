data "aws_iam_policy_document" "karpenter_controller_ec2" {
  count = var.create ? 1 : 0

  statement {
    sid = "AllowScopedEC2InstanceAccessActions"
    resources = [
      "arn:${local.partition}:ec2:${var.aws_region}::image/*",
      "arn:${local.partition}:ec2:${var.aws_region}::snapshot/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:security-group/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:subnet/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:capacity-reservation/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:placement-group/*"
    ]
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]
  }

  statement {
    sid = "AllowScopedEC2LaunchTemplateAccessActions"
    resources = [
      "arn:${local.partition}:ec2:${var.aws_region}:*:launch-template/*"
    ]
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedEC2InstanceActionsWithTags"
    resources = [
      "arn:${local.partition}:ec2:${var.aws_region}:*:fleet/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:instance/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:volume/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:network-interface/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:launch-template/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:spot-instances-request/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:capacity-reservation/*"
    ]
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.cluster_name]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedResourceCreationTagging"
    resources = [
      "arn:${local.partition}:ec2:${var.aws_region}:*:fleet/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:instance/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:volume/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:network-interface/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:launch-template/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:spot-instances-request/*",
    ]
    actions = ["ec2:CreateTags"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.cluster_name]
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "RunInstances",
        "CreateFleet",
        "CreateLaunchTemplate",
      ]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowScopedResourceTagging"
    resources = ["arn:${local.partition}:ec2:${var.aws_region}:*:instance/*"]
    actions   = ["ec2:CreateTags"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.cluster_name]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values = [
        "eks:eks-cluster-name",
        "karpenter.sh/nodeclaim",
        "Name",
      ]
    }
  }

  statement {
    sid = "AllowScopedDeletion"
    resources = [
      "arn:${local.partition}:ec2:${var.aws_region}:*:instance/*",
      "arn:${local.partition}:ec2:${var.aws_region}:*:launch-template/*"
    ]
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowRegionalReadActions"
    resources = ["*"]
    actions = [
      "ec2:DescribeCapacityReservations",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DescribePlacementGroups",
      "ec2:DescribeInstanceStatus",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

data "aws_iam_policy_document" "karpenter_controller_services" {
  count = var.create ? 1 : 0

  statement {
    sid       = "AllowSSMReadActions"
    resources = local.ssm_parameter_resources
    actions   = ["ssm:GetParameter"]
  }

  statement {
    sid       = "AllowPricingReadActions"
    resources = ["*"]
    actions   = ["pricing:GetProducts"]
  }

  statement {
    sid       = "AllowInterruptionQueueActions"
    resources = [var.interruption_queue_arn]
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage"
    ]
  }

  statement {
    sid       = "AllowKMSDecryptForSQSEncryptedMessages"
    resources = [var.kms_key_arn]
    actions   = ["kms:Decrypt"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sqs.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowPassingInstanceRole"
    resources = [aws_iam_role.node[0].arn]
    actions   = ["iam:PassRole"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = tolist(distinct([local.ec2_sp_name, "ec2.amazonaws.com"]))
    }
  }

  statement {
    sid       = "AllowScopedInstanceProfileCreationActions"
    resources = ["arn:${local.partition}:iam::${local.account_id}:instance-profile/*"]
    actions   = ["iam:CreateInstanceProfile"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.cluster_name]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowScopedInstanceProfileTagActions"
    resources = ["arn:${local.partition}:iam::${local.account_id}:instance-profile/*"]
    actions   = ["iam:TagInstanceProfile"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.cluster_name]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowScopedInstanceProfileActions"
    resources = ["arn:${local.partition}:iam::${local.account_id}:instance-profile/*"]
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowInstanceProfileReadActions"
    resources = ["arn:${local.partition}:iam::${local.account_id}:instance-profile/*"]
    actions   = ["iam:GetInstanceProfile"]
  }

  statement {
    sid       = "AllowUnscopedInstanceProfileListAction"
    resources = ["*"]
    actions   = ["iam:ListInstanceProfiles"]
  }

  statement {
    sid       = "AllowAPIServerEndpointDiscovery"
    resources = ["arn:${local.partition}:eks:${var.aws_region}:${local.account_id}:cluster/${var.cluster_name}"]
    actions   = ["eks:DescribeCluster"]
  }

  statement {
    sid       = "AllowScopedKMSUsage"
    resources = [var.kms_key_arn]
    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKeyWithoutPlaintext",
    ]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowScopedKMSGrant"
    resources = [var.kms_key_arn]
    actions   = ["kms:CreateGrant"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}
