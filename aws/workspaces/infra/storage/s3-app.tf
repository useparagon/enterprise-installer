resource "aws_s3_bucket" "app" {
  bucket        = var.migrated ? var.workspace : "${var.workspace}-app"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_logging" "app" {
  bucket = aws_s3_bucket.app.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/app/"
}

resource "aws_s3_bucket_ownership_controls" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.s3_kms_enabled ? "aws:kms" : "AES256"
      kms_master_key_id = local.s3_kms_enabled ? local.s3_kms_key_arn : null
    }
    bucket_key_enabled = local.s3_kms_enabled ? true : null
  }
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "expiration"
    status = "Enabled"

    filter {}

    expiration {
      days = var.app_bucket_expiration
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "delete-markers"
    status = "Enabled"

    filter {}

    expiration {
      expired_object_delete_marker = true
    }
  }
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "AllowSSLRequestsOnly"
    actions   = ["s3:*"]
    effect    = "Deny"
    resources = [aws_s3_bucket.app.arn, "${aws_s3_bucket.app.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.app.json
}

# EKS Pod Identity role for Paragon microservices that access app/cdn/auditlogs S3 buckets.
# Associations (SA → role) are created in the paragon workspace.
data "aws_iam_policy_document" "app_assume" {
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

resource "aws_iam_role" "app" {
  name               = "${var.workspace}-s3"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json

  tags = {
    Name = "${var.workspace}-s3"
  }
}

resource "aws_iam_role_policy" "app" {
  name = "${var.workspace}-s3-policy"
  role = aws_iam_role.app.id

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : concat([
        {
          "Sid" : "AllowReadBucketOperations",
          "Action" : [
            "s3:GetBucketAcl",
            "s3:GetBucketCORS",
            "s3:GetBucketLocation",
            "s3:GetBucketPolicy",
            "s3:GetBucketVersioning",
            "s3:GetEncryptionConfiguration",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads"
          ],
          "Effect" : "Allow",
          "Resource" : concat([
            aws_s3_bucket.app.arn,
            aws_s3_bucket.cdn.arn,
            aws_s3_bucket.auditlogs.arn
            ], var.managed_sync_enabled ? [
            aws_s3_bucket.managed_sync[0].arn
          ] : [])
        },
        {
          "Sid" : "AllowReadObjectOperations",
          "Action" : [
            "s3:GetObject",
            "s3:GetObjectAcl",
            "s3:GetObjectRetention",
            "s3:ListMultipartUploadParts"
          ],
          "Effect" : "Allow",
          "Resource" : concat([
            "${aws_s3_bucket.app.arn}/*",
            "${aws_s3_bucket.cdn.arn}/*",
            "${aws_s3_bucket.auditlogs.arn}/*"
            ], var.managed_sync_enabled ? [
            "${aws_s3_bucket.managed_sync[0].arn}/*"
          ] : [])
        },
        {
          "Sid" : "AllowPutAndDeleteObjectOperations",
          "Action" : [
            "s3:AbortMultipartUpload",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:PutObject",
            "s3:PutObjectLegalHold"
          ],
          "Effect" : "Allow",
          "Resource" : concat([
            "${aws_s3_bucket.app.arn}/*",
            "${aws_s3_bucket.cdn.arn}/*",
            "${aws_s3_bucket.auditlogs.arn}/*"
            ], var.managed_sync_enabled ? [
            "${aws_s3_bucket.managed_sync[0].arn}/*"
          ] : [])
        }
        ], local.s3_kms_enabled ? [
        {
          "Sid" : "AllowS3KMSEncryption",
          "Action" : [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:ReEncrypt*"
          ],
          "Effect" : "Allow",
          "Resource" : [local.s3_kms_key_arn]
        }
      ] : [])
    }
  )
}

# Agent OS bucket and dedicated Pod Identity role for parsed documents and index data.
# Static credentials stay out of Agent OS secrets.

resource "aws_s3_bucket" "agent_os" {
  count         = var.agent_os_enabled ? 1 : 0
  bucket        = "${var.workspace}-agent-os"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_logging" "agent_os" {
  count  = var.agent_os_enabled ? 1 : 0
  bucket = aws_s3_bucket.agent_os[0].id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/agent-os/"
}

resource "aws_s3_bucket_ownership_controls" "agent_os" {
  count  = var.agent_os_enabled ? 1 : 0
  bucket = aws_s3_bucket.agent_os[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "agent_os" {
  count  = var.agent_os_enabled ? 1 : 0
  bucket = aws_s3_bucket.agent_os[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.agent_os_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "agent_os" {
  count  = var.agent_os_enabled ? 1 : 0
  bucket = aws_s3_bucket.agent_os[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "agent_os" {
  count  = var.agent_os_enabled ? 1 : 0
  bucket = aws_s3_bucket.agent_os[0].bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  statement {
    sid       = "AllowSSLRequestsOnly"
    actions   = ["s3:*"]
    effect    = "Deny"
    resources = [aws_s3_bucket.agent_os[0].arn, "${aws_s3_bucket.agent_os[0].arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "agent_os" {
  count  = var.agent_os_enabled ? 1 : 0
  bucket = aws_s3_bucket.agent_os[0].id
  policy = data.aws_iam_policy_document.agent_os[0].json
}

data "aws_iam_policy_document" "agent_os_assume" {
  count = var.agent_os_enabled ? 1 : 0

  statement {
    sid     = "PodIdentity"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-cluster-name"
      values   = [var.workspace]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = ["agent-os"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = ["agent-os"]
    }
  }
}

resource "aws_iam_role" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name               = "${var.workspace}-agent-os-s3"
  assume_role_policy = data.aws_iam_policy_document.agent_os_assume[0].json

  tags = {
    Name = "${var.workspace}-agent-os-s3"
  }
}

data "aws_iam_policy_document" "agent_os_workload" {
  count = var.agent_os_enabled ? 1 : 0

  statement {
    sid = "BucketAccess"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [aws_s3_bucket.agent_os[0].arn]
  }

  statement {
    sid = "ObjectAccess"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.agent_os[0].arn}/*"]
  }

  statement {
    sid = "KMSAccess"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
    ]
    resources = [var.agent_os_kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values = [
        aws_s3_bucket.agent_os[0].arn,
        "${aws_s3_bucket.agent_os[0].arn}/*",
      ]
    }
  }
}

resource "aws_iam_role_policy" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name   = "${var.workspace}-agent-os-s3-policy"
  role   = aws_iam_role.agent_os[0].id
  policy = data.aws_iam_policy_document.agent_os_workload[0].json
}
