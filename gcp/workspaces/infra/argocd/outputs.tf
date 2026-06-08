output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = var.argocd_namespace
}

output "eso_gsa_email" {
  description = "GSA email for the External Secrets Operator."
  value       = google_service_account.eso.email
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore."
  value       = var.cluster_secret_store_name
}

output "argocd_helm_release" {
  description = "ArgoCD Helm release name."
  value       = var.argocd_release_name
}

output "gitops_bridge_secret_name" {
  description = "Name of the GitOps bridge cluster secret."
  value       = "${var.argocd_release_name}-cluster"
}
