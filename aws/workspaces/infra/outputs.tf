output "workspace" {
  description = "The resource group that all resources are associated with."
  value       = local.workspace
}

output "postgres" {
  description = "Connection info for Postgres."
  value       = module.postgres.rds
  sensitive   = true
}

output "redis" {
  description = "Connection information for Redis."
  value       = module.redis.elasticache
  sensitive   = true
}

output "kafka" {
  description = "Connection info for Kafka."
  value = var.managed_sync_enabled ? {
    cluster_bootstrap_brokers = module.kafka[0].cluster_bootstrap_brokers_sasl_scram
    cluster_username          = module.kafka[0].kafka_credentials.username
    cluster_password          = module.kafka[0].kafka_credentials.password
    cluster_mechanism         = module.kafka[0].kafka_credentials.mechanism
    cluster_tls_enabled       = module.kafka[0].cluster_tls_enabled
  } : {}
  sensitive = true
}

output "logs_bucket" {
  description = "The bucket used to store system logs."
  value       = module.storage.s3.logs_bucket
  sensitive   = true
}

output "auditlogs_bucket" {
  description = "The bucket used to store audit logs."
  value       = module.storage.s3.auditlogs_bucket
  sensitive   = true
}

output "storage" {
  description = "Object storage connection info. S3 access uses EKS Pod Identity (role_arn); static access keys are no longer provisioned."
  value = {
    public_bucket       = module.storage.s3.public_bucket
    private_bucket      = module.storage.s3.private_bucket
    managed_sync_bucket = module.storage.s3.managed_sync_bucket
    role_arn            = module.storage.s3.role_arn
    kms_key_arn         = module.storage.s3.kms_key_arn
  }
  sensitive = true
}

output "bastion" {
  description = "Bastion server connection info."
  value = var.bastion_enabled ? {
    public_dns  = module.bastion[0].connection.bastion_dns
    private_key = module.bastion[0].connection.private_key
  } : null
  sensitive = true
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.cluster.eks_cluster.name
  sensitive   = true
}

output "enable_karpenter" {
  description = "Whether Karpenter autoscaling is enabled. Consumed by paragon workspace for EC2NodeClass and NodePool manifests."
  value       = module.cluster.enable_karpenter
}

output "k8s_version" {
  description = "EKS control plane version. Consumed by paragon workspace for Karpenter drift tagging."
  value       = module.cluster.k8s_version
}

output "enable_legacy_mng_pools" {
  description = "Whether legacy on-demand and spot managed node groups are active. Consumed by paragon workspace for conditional AWS Node Termination Handler (NTH) deployment on legacy managed node groups."
  value       = module.cluster.enable_legacy_mng_pools
}

output "karpenter" {
  description = "AWS resources created by infra for Karpenter worker nodes. Consumed by paragon workspace."
  value       = module.cluster.karpenter
}

output "secrets_manager_env_secret" {
  description = "Name of the Secrets Manager secret containing Paragon env config."
  value       = module.secrets.env_secret_name
  sensitive   = true
}

output "secrets_manager_secret_arns" {
  description = "ARNs of application Secrets Manager secrets."
  value       = module.secrets.secret_arns
}
