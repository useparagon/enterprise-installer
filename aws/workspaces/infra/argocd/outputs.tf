output "argocd_namespace" {
  description = "The namespace ArgoCD is installed in."
  value       = var.argocd_enabled ? var.argocd_namespace : null
}

output "eso_role_arn" {
  description = "IAM role ARN used by the External Secrets Operator."
  value       = var.argocd_enabled ? aws_iam_role.eso[0].arn : null
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by the cluster-autoscaler service account."
  value       = var.argocd_enabled && var.cluster_autoscaler_enabled ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for AWS Secrets Manager."
  value       = var.argocd_enabled ? var.cluster_secret_store_name : null
}

output "argocd_helm_release" {
  description = "Name of the Helm release that installs Argo CD."
  value       = var.argocd_enabled ? var.argocd_release_name : null
}

output "gitops_bridge_secret_name" {
  description = "ArgoCD in-cluster secret annotated with GitOps bridge metadata."
  value       = var.argocd_enabled ? "${var.argocd_release_name}-cluster" : null
}

output "env_secret_name" {
  description = "Name of the environment config secret in Secrets Manager."
  value       = var.env_secret_name
  sensitive   = true
}

output "paragon_certificate_arn" {
  description = "ACM certificate ARN used for Paragon ALB ingress."
  value       = var.argocd_enabled ? local.paragon_certificate_arn_resolved : null
}

output "paragon_route53_zone_id" {
  description = "Route 53 hosted zone ID for paragon_domain."
  value       = local.create_dns_zone ? aws_route53_zone.paragon[0].zone_id : null
}

output "paragon_route53_name_servers" {
  description = "Route 53 name servers for paragon_domain."
  value       = local.create_dns_zone ? aws_route53_zone.paragon[0].name_servers : null
}
