resource "aws_s3_bucket" "logs" {
  bucket        = "${var.workspace}-logs"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Always SSE-S3: this bucket receives ALB access logs and S3 server access logs,
# neither of which support SSE-KMS destination buckets (delivery fails / objects
# remain SSE-S3). Do not switch this bucket to aws:kms.
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "logs_bucket_policy" {
  statement {
    sid     = "AllowAccessLogs"
    actions = ["s3:PutObject"]
    effect  = "Allow"
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/access_logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }

  statement {
    sid = "AllowAppLogs"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  dynamic "statement" {
    for_each = var.network_firewall_enabled ? [1] : []
    content {
      sid    = "AWSLogDeliveryWriteNetworkFirewall"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      actions = ["s3:PutObject"]
      resources = [
        "${aws_s3_bucket.logs.arn}/network-firewall/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
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
  }

  dynamic "statement" {
    for_each = var.network_firewall_enabled ? [1] : []
    content {
      sid    = "AWSLogDeliveryAclCheckNetworkFirewall"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      actions = [
        "s3:GetBucketAcl",
        "s3:ListBucket",
      ]
      resources = [aws_s3_bucket.logs.arn]

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
}

resource "aws_s3_bucket_policy" "logs_bucket" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket_policy.json
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "abort-incomplete"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "expire-files"
    status = "Enabled"

    filter {
      prefix = "files/"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "expire-s3-access-logs"
    status = "Enabled"

    filter {
      prefix = "s3/"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "expire-alb-access-logs"
    status = "Enabled"

    filter {
      prefix = "access_logs/"
    }

    expiration {
      days = 365
    }
  }

  dynamic "rule" {
    for_each = var.network_firewall_enabled ? [1] : []
    content {
      id     = "expire-network-firewall-logs"
      status = "Enabled"

      filter {
        prefix = "network-firewall/"
      }

      expiration {
        days = 365
      }
    }
  }
}
