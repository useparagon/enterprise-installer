output "kubernetes" {
  value = {
    name                   = module.gke.name
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.paragon.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
  sensitive = true
}

output "cluster_id" {
  value       = module.gke.cluster_id
  description = "Full GKE cluster resource ID used to register the cluster with Fleet."
}