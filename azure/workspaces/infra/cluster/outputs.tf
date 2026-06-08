output "kubernetes" {
  value = {
    id                     = azurerm_kubernetes_cluster.cluster.id
    name                   = azurerm_kubernetes_cluster.cluster.name
    host                   = azurerm_kubernetes_cluster.cluster.kube_config.0.host
    client_certificate     = azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate
    client_key             = azurerm_kubernetes_cluster.cluster.kube_config.0.client_key
    cluster_ca_certificate = azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate
    node_resource_group    = azurerm_kubernetes_cluster.cluster.node_resource_group
    kube_config            = azurerm_kubernetes_cluster.cluster.kube_config_raw
  }
  sensitive = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federation."
  value       = azurerm_kubernetes_cluster.cluster.oidc_issuer_url
}

output "wait_for_cluster" {
  description = "Variable that can be referenced to ensure cluster is initialized."
  value       = azurerm_kubernetes_cluster.cluster.fqdn
}
