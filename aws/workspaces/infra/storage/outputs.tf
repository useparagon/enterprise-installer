output "logs_bucket_name" {
  description = "Central logs bucket name (non-sensitive wiring for Network Firewall)."
  value       = aws_s3_bucket.logs.bucket
}

output "s3" {
  value = {
    role_arn             = aws_iam_role.app.arn
    private_bucket       = aws_s3_bucket.app.bucket
    public_bucket        = aws_s3_bucket.cdn.bucket
    auditlogs_bucket     = aws_s3_bucket.auditlogs.bucket
    logs_bucket          = aws_s3_bucket.logs.bucket
    managed_sync_bucket  = var.managed_sync_enabled ? aws_s3_bucket.managed_sync[0].bucket : null
    agent_os_bucket      = var.agent_os_enabled ? aws_s3_bucket.agent_os[0].bucket : null
    agent_os_kms_key_arn = var.agent_os_enabled ? var.agent_os_kms_key_arn : null
    agent_os_role_arn    = var.agent_os_enabled ? aws_iam_role.agent_os[0].arn : null
    kms_key_arn          = local.s3_kms_key_arn
  }
  sensitive = true
}
