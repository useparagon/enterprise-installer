locals {
  runtime_secret_prefix = "paragon/${local.workspace}"
}

resource "aws_secretsmanager_secret" "runtime_postgres" {
  name                    = "${local.runtime_secret_prefix}/postgres"
  description             = "Raw Postgres connection info for ${var.organization}"
  recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = {
    Name         = "${local.runtime_secret_prefix}/postgres"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "runtime_postgres" {
  secret_id     = aws_secretsmanager_secret.runtime_postgres.id
  secret_string = jsonencode(module.postgres.rds)
}

resource "aws_secretsmanager_secret" "runtime_redis" {
  name                    = "${local.runtime_secret_prefix}/redis"
  description             = "Raw Redis connection info for ${var.organization}"
  recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = {
    Name         = "${local.runtime_secret_prefix}/redis"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "runtime_redis" {
  secret_id     = aws_secretsmanager_secret.runtime_redis.id
  secret_string = jsonencode(module.redis.elasticache)
}

resource "aws_secretsmanager_secret" "runtime_storage" {
  name                    = "${local.runtime_secret_prefix}/storage"
  description             = "Raw object storage connection info for ${var.organization}"
  recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = {
    Name         = "${local.runtime_secret_prefix}/storage"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "runtime_storage" {
  secret_id = aws_secretsmanager_secret.runtime_storage.id
  secret_string = jsonencode({
    public_bucket       = module.storage.s3.public_bucket
    private_bucket      = module.storage.s3.private_bucket
    managed_sync_bucket = module.storage.s3.managed_sync_bucket
    microservice_user   = module.storage.s3.minio_microservice_user
    microservice_pass   = module.storage.s3.minio_microservice_pass
    root_user           = module.storage.s3.access_key_id
    root_password       = module.storage.s3.access_key_secret
  })
}

resource "aws_secretsmanager_secret" "runtime_kafka" {
  count = var.managed_sync_enabled ? 1 : 0

  name                    = "${local.runtime_secret_prefix}/kafka"
  description             = "Raw Kafka connection info for ${var.organization}"
  recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = {
    Name         = "${local.runtime_secret_prefix}/kafka"
    Organization = var.organization
  }
}

resource "aws_secretsmanager_secret_version" "runtime_kafka" {
  count = var.managed_sync_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.runtime_kafka[0].id
  secret_string = jsonencode({
    cluster_bootstrap_brokers = module.kafka[0].cluster_bootstrap_brokers_sasl_scram
    cluster_username          = module.kafka[0].kafka_credentials.username
    cluster_password          = module.kafka[0].kafka_credentials.password
    cluster_mechanism         = module.kafka[0].kafka_credentials.mechanism
    cluster_tls_enabled       = module.kafka[0].cluster_tls_enabled
  })
}
