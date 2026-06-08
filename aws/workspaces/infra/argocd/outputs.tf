output "argocd_namespace" {
  description = "The namespace ArgoCD is installed in."
  value       = var.argocd_namespace
}

output "eso_role_arn" {
  description = "IAM role ARN used by the External Secrets Operator."
  value       = var.eso_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by the cluster-autoscaler service account."
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for AWS Secrets Manager."
  value       = "aws-secrets-manager"
}

output "argocd_helm_release" {
  description = "Name of the Helm release that installs Argo CD."
  value       = var.argocd_release_name
}

output "gitops_bridge_secret_name" {
  description = "ArgoCD in-cluster secret annotated with GitOps bridge metadata (EKS Blueprints pattern)."
  value       = "${var.argocd_release_name}-cluster"
}
