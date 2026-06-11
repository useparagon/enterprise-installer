data "aws_caller_identity" "current" {}

locals {
  waf_logs_bucket_name = "aws-waf-logs-${lower(replace(var.workspace, "_", "-"))}"
}

resource "aws_s3_bucket" "waf_logs" {
  count = var.waf_logs_enabled ? 1 : 0

  bucket        = local.waf_logs_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "waf_logs" {
  count = var.waf_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.waf_logs[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs" {
  count = var.waf_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.waf_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "waf_logs" {
  count = var.waf_logs_enabled ? 1 : 0

  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.waf_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.waf_logs[0].arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_s3_bucket_policy" "waf_logs" {
  count = var.waf_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.waf_logs[0].id
  policy = data.aws_iam_policy_document.waf_logs[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "waf_logs" {
  count = var.waf_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.waf_logs[0].id

  rule {
    id     = "expire-waf-logs"
    status = "Enabled"

    filter {
      prefix = "AWSLogs/"
    }

    expiration {
      days = var.waf_logs_retention_days
    }
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.waf_logs_enabled ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_s3_bucket.waf_logs[0].arn]

  depends_on = [aws_s3_bucket_policy.waf_logs]
}
