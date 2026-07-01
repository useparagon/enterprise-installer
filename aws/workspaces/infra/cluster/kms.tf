locals {
  key_administrators = distinct(compact(concat(
    var.eks_admin_arns,
    var.kms_admin_role != null ? [var.kms_admin_role] : [],
    [local.autoscaling_role_arn]
  )))
}

data "aws_partition" "current" {}

module "ebs_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "3.1.0"

  description             = "${var.workspace} ebs encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  aliases_use_name_prefix = false

  key_administrators = local.key_administrators

  key_service_roles_for_autoscaling = [
    # required for the ASG to manage encrypted volumes for nodes - since this role is unique to an account we can't reliably create it
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    # required for the cluster / persistentvolume-controller to create encrypted PVCs
    module.eks.cluster_iam_role_arn,
  ]
  computed_aliases = {
    ebs = { name = "eks/${var.workspace}/ebs" }
  }

  key_statements = var.enable_karpenter ? [
    {
      sid = "AllowSQSServiceAccountScoped"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["sqs.amazonaws.com"]
      }]
      resources = ["*"]
      condition = [{
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }]
    },
    {
      sid = "AllowEventBridgeServiceAccountScoped"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }]
      resources = ["*"]
      condition = [{
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }]
    },
    {
      sid = "AllowEBSVolumeEncryptionViaEC2"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      principals = [{
        type        = "AWS"
        identifiers = ["*"]
      }]
      resources = ["*"]
      condition = [
        {
          test     = "StringEquals"
          variable = "kms:CallerAccount"
          values   = [data.aws_caller_identity.current.account_id]
        },
        {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["ec2.${var.aws_region}.amazonaws.com"]
        },
      ]
    },
    {
      sid     = "AllowAttachmentOfPersistentResourcesViaEC2"
      actions = ["kms:CreateGrant"]
      principals = [{
        type        = "AWS"
        identifiers = ["*"]
      }]
      resources = ["*"]
      condition = [
        {
          test     = "StringEquals"
          variable = "kms:CallerAccount"
          values   = [data.aws_caller_identity.current.account_id]
        },
        {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["ec2.${var.aws_region}.amazonaws.com"]
        },
        {
          test     = "Bool"
          variable = "kms:GrantIsForAWSResource"
          values   = ["true"]
        },
      ]
    },
  ] : []
}

module "cluster_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "3.1.0"

  description             = "${var.workspace} cluster encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  aliases_use_name_prefix = false

  key_administrators = local.key_administrators

  key_users = [
    module.eks.cluster_iam_role_arn
  ]
  computed_aliases = {
    cluster = { name = "eks/${var.workspace}/cluster" }
  }
}
