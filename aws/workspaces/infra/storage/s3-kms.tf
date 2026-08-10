locals {
  s3_kms_enabled = var.s3_kms_encryption_enabled

  # Use a caller-provided key when given; otherwise the key created below. Null when
  # KMS encryption is disabled so the SSE configs fall back to SSE-S3 (AES256).
  s3_kms_key_arn = local.s3_kms_enabled ? coalesce(var.s3_kms_key_arn, try(module.s3_kms_key[0].key_arn, null)) : null
}

# Dedicated customer-managed key for S3 object encryption. Only created when KMS
# encryption is enabled and the caller did not bring their own key.
module "s3_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "3.1.0"

  count = local.s3_kms_enabled && var.s3_kms_key_arn == null ? 1 : 0

  description             = "${var.workspace} s3 encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  aliases_use_name_prefix = false

  key_administrators = var.admin_arns

  # Pod Identity role used by Paragon workloads to read/write encrypted objects
  key_users = [aws_iam_role.app.arn]

  computed_aliases = {
    s3 = { name = "s3/${var.workspace}" }
  }
}
