output "workspace" {
  description = "The resource group that all resources are associated with."
  value       = local.workspace
}

output "bastion" {
  description = "Bastion server connection info."
  value = var.bastion_enabled ? {
    public_dns  = module.bastion[0].connection.bastion_dns
    private_key = module.bastion[0].connection.private_key
  } : null
  sensitive = true
}

output "postgres" {
  description = "Connection info for Postgres."
  value       = local.postgres_runtime
  sensitive   = true
}

output "logs_container" {
  description = "The bucket used to store system logs."
  value       = module.storage.blob.logs_container
  sensitive   = true
}

output "auditlogs_bucket" {
  description = "The bucket used to store audit logs."
  value       = module.storage.blob.auditlogs_container
  sensitive   = true
}

output "storage" {
  description = "Object storage connection info."
  value = {
    public_bucket       = module.storage.blob.public_container
    private_bucket      = module.storage.blob.private_container
    managed_sync_bucket = module.storage.blob.managed_sync_container
    root_user           = module.storage.blob.name
    root_password       = module.storage.blob.access_key
  }
  sensitive = true
}

output "redis" {
  description = "Connection info for installer-managed Azure Cache for Redis. Null when redis_enabled is false."
  value       = local.redis_runtime
  sensitive   = true
}

output "redis_managed" {
  description = "Azure Managed Redis 7.4 endpoints (null when redis_managed_enabled is false). Use during migration for kubectl trial routing while output redis still points at legacy."
  value       = var.redis_managed_enabled ? module.redis_managed[0].redis : null
  sensitive   = true
}

output "redis_managed_export_storage" {
  description = "Blob storage for on-demand Azure Managed Redis RDB export (null when disabled or legacy Redis)."
  value       = var.redis_managed_enabled ? module.redis_managed[0].export_storage : null
}

output "cluster_name" {
  description = "The name of the AKS cluster."
  value       = module.cluster.kubernetes.name
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "AKS OIDC issuer URL for workload-identity federated credentials (AGC ALB controller)."
  value       = module.cluster.oidc_issuer_url
}

output "resource_group" {
  description = "Resource Group that infrastructure was deployed to."
  value = {
    name     = module.network.resource_group.name
    location = module.network.resource_group.location
  }
}

output "network" {
  description = "Network identifiers for AGC association subnet and nginx internal LB wiring."
  value = {
    private_subnet_id   = module.network.private_subnet.id
    private_subnet_cidr = module.network.private_subnet.address_prefixes[0]
    agc_subnet_id       = var.agc_subnet_enabled ? module.network.agc_subnet.id : null
    agc_subnet_cidr     = var.agc_subnet_enabled ? module.network.agc_subnet.address_prefixes[0] : null
  }
}

output "kafka" {
  description = "Connection info for Kafka (Event Hubs for Kafka)."
  value = var.managed_sync_enabled ? {
    cluster_bootstrap_brokers = module.kafka[0].bootstrap_servers
    bootstrap_servers_private = module.kafka[0].bootstrap_servers_private
    namespace_name            = module.kafka[0].namespace_name
    cluster_username          = module.kafka[0].kafka_credentials.username
    cluster_password          = module.kafka[0].kafka_credentials.password
    cluster_mechanism         = module.kafka[0].kafka_credentials.mechanism
    cluster_tls_enabled       = module.kafka[0].tls_enabled
  } : null
  sensitive = true
}
