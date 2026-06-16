output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = var.argocd_enabled ? var.argocd_namespace : null
}

output "eso_gsa_email" {
  description = "GSA email for the External Secrets Operator."
  value       = var.argocd_enabled ? google_service_account.eso[0].email : null
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore."
  value       = var.argocd_enabled ? var.cluster_secret_store_name : null
}

output "argocd_helm_release" {
  description = "ArgoCD Helm release name."
  value       = var.argocd_enabled ? var.argocd_release_name : null
}

output "gitops_bridge_secret_name" {
  description = "Name of the GitOps bridge cluster secret."
  value       = var.argocd_enabled ? "${var.argocd_release_name}-cluster" : null
}
