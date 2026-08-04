output "grafana_role_arn" {
  description = "IAM role ARN for Grafana CloudWatch access via Pod Identity."
  value       = aws_iam_role.grafana.arn
}
