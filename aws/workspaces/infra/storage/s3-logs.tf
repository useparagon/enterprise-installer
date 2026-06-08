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
      "${aws_s3_bucket.logs.arn}",
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
      "${aws_s3_bucket.logs.arn}",
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
}

resource "aws_s3_bucket_policy" "logs_bucket" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket_policy.json
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expiration"
    status = "Enabled"

    filter {
      prefix = "files/"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "markers"
    status = "Enabled"

    filter {
      prefix = "files/"
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}
