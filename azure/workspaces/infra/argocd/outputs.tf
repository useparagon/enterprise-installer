output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = var.argocd_enabled ? var.argocd_namespace : null
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore used by ESO."
  value       = var.argocd_enabled ? var.cluster_secret_store_name : null
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault holding GitOps secrets."
  value       = var.argocd_enabled ? var.key_vault_uri : null
}

output "eso_client_id" {
  description = "Client ID of the ESO managed identity (for diagnostics)."
  value       = var.argocd_enabled ? azurerm_user_assigned_identity.eso[0].client_id : null
}

output "argocd_helm_release" {
  description = "Name of the ArgoCD Helm release."
  value       = var.argocd_enabled ? var.argocd_release_name : null
}

output "gitops_bridge_secret_name" {
  description = "Name of the GitOps bridge cluster secret."
  value       = var.argocd_enabled ? "${var.argocd_release_name}-cluster" : null
}
