output "cluster_admin_token" {
  description = "Token used by the Hoop Kubernetes connection."
  value       = data.kubernetes_secret.hoop_cluster_admin_token.data["token"]
  sensitive   = true
}

output "support_role_arn" {
  description = "IRSA role ARN used by the Hoop agent."
  value       = aws_iam_role.hoop_support.arn
}
