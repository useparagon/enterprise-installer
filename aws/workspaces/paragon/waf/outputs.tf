output "web_acl_arn" {
  description = "ARN of the regional WAFv2 Web ACL."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the regional WAFv2 Web ACL."
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_name" {
  description = "Name of the regional WAFv2 Web ACL."
  value       = aws_wafv2_web_acl.this.name
}

output "waf_logs_bucket" {
  description = "S3 bucket name for WAF traffic logs when logging is enabled."
  value       = var.waf_logs_enabled ? aws_s3_bucket.waf_logs[0].id : null
}
