output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = var.argocd_namespace
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore used by ESO."
  value       = var.cluster_secret_store_name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault holding GitOps secrets."
  value       = var.key_vault_uri
}

output "eso_client_id" {
  description = "Client ID of the ESO managed identity (for diagnostics)."
  value       = azurerm_user_assigned_identity.eso.client_id
}

output "argocd_helm_release" {
  description = "Name of the ArgoCD Helm release."
  value       = var.argocd_release_name
}

output "gitops_bridge_secret_name" {
  description = "Name of the GitOps bridge cluster secret."
  value       = "${var.argocd_release_name}-cluster"
}
