output "workspace" {
  description = "The resource group that all resources are associated with."
  value       = local.workspace
}

output "bastion" {
  description = "Bastion server connection info."
  value = {
    public_dns  = module.bastion.connection.bastion_dns
    private_key = module.bastion.connection.private_key
  }
  sensitive = true
}

output "postgres" {
  description = "Connection info for Postgres."
  value       = module.postgres.postgres
  sensitive   = true
}

output "logs_container" {
  description = "The bucket used to store system logs."
  value       = module.storage.storage.logs_bucket
  sensitive   = true
}

output "logs_bucket" {
  description = "Alias for logs_container; used by paragon for managed-sync ingress.logsBucket."
  value       = module.storage.storage.logs_bucket
  sensitive   = true
}

output "auditlogs_bucket" {
  description = "The bucket used to store audit logs."
  value       = module.storage.storage.auditlogs_bucket
  sensitive   = true
}

output "storage" {
  description = "Object storage connection info."
  value = {
    public_bucket       = module.storage.storage.public_bucket
    private_bucket      = module.storage.storage.private_bucket
    managed_sync_bucket = module.storage.storage.managed_sync_bucket
    root_user           = module.storage.storage.project_id
    root_password       = module.storage.storage.private_key
    service_account     = module.storage.storage.service_account
  }
  sensitive = true
}

output "redis" {
  description = "Connection information for Redis."
  value       = module.redis.redis
  sensitive   = true
}

output "kafka" {
  description = "Connection info for Kafka (Managed Sync). OAUTHBEARER or PLAIN; when PLAIN, use cluster_password_file_path for key JSON."
  value = var.managed_sync_enabled ? {
    cluster_bootstrap_brokers     = module.kafka[0].cluster_bootstrap_brokers
    cluster_service_account_email = module.kafka[0].cluster_service_account_email
    cluster_username              = module.kafka[0].cluster_username
    cluster_password              = module.kafka[0].cluster_password
    cluster_password_file_path    = module.kafka[0].cluster_password_file_path
    cluster_mechanism             = module.kafka[0].cluster_mechanism
    cluster_tls_enabled           = module.kafka[0].cluster_tls_enabled
  } : {}
  sensitive = true
}

output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = module.cluster.kubernetes.name
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = var.argocd_enabled ? module.argocd[0].argocd_namespace : null
}

output "cluster_secret_store_name" {
  description = "Name of the GCP Secret Manager ClusterSecretStore."
  value       = var.argocd_enabled ? module.argocd[0].cluster_secret_store_name : null
}

output "eso_gsa_email" {
  description = "GSA email for the External Secrets Operator."
  value       = var.argocd_enabled ? module.argocd[0].eso_gsa_email : null
}
