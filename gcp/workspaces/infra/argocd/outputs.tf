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

# Ingress references consumed by the chart shared-ingress via global.ingress.*.
output "ingress_static_ip_name" {
  description = "Name of the reserved global static IP (global.ingress.loadBalancerName)."
  value       = local.gitops_ingress_enabled ? google_compute_global_address.loadbalancer[0].name : null
}

output "ingress_static_ip_address" {
  description = "Reserved global static IP address for the shared Ingress."
  value       = local.gitops_ingress_enabled ? google_compute_global_address.loadbalancer[0].address : null
}

output "ingress_certificate_map_name" {
  description = "Certificate Manager cert-map name (global.ingress.certificate)."
  value       = local.gitops_ingress_enabled ? google_certificate_manager_certificate_map.paragon[0].name : null
}
