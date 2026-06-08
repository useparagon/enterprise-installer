locals {
  runtime_secret_prefix = local.workspace
}

resource "google_secret_manager_secret" "runtime_postgres" {
  secret_id = "${local.runtime_secret_prefix}-postgres"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_postgres" {
  secret      = google_secret_manager_secret.runtime_postgres.id
  secret_data = jsonencode(module.postgres.postgres)
}

resource "google_secret_manager_secret" "runtime_redis" {
  secret_id = "${local.runtime_secret_prefix}-redis"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_redis" {
  secret      = google_secret_manager_secret.runtime_redis.id
  secret_data = jsonencode(module.redis.redis)
}

resource "google_secret_manager_secret" "runtime_storage" {
  secret_id = "${local.runtime_secret_prefix}-storage"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_storage" {
  secret = google_secret_manager_secret.runtime_storage.id
  secret_data = jsonencode({
    public_bucket       = module.storage.storage.public_bucket
    private_bucket      = module.storage.storage.private_bucket
    managed_sync_bucket = module.storage.storage.managed_sync_bucket
    microservice_user   = module.storage.storage.minio_microservice_user
    microservice_pass   = module.storage.storage.minio_microservice_pass
    root_user           = module.storage.storage.project_id
    root_password       = module.storage.storage.private_key
    service_account     = module.storage.storage.service_account
  })
}

resource "google_secret_manager_secret" "runtime_kafka" {
  count     = var.managed_sync_enabled ? 1 : 0
  secret_id = "${local.runtime_secret_prefix}-kafka"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_kafka" {
  count       = var.managed_sync_enabled ? 1 : 0
  secret      = google_secret_manager_secret.runtime_kafka[0].id
  secret_data = jsonencode({
    cluster_bootstrap_brokers     = module.kafka[0].cluster_bootstrap_brokers
    cluster_service_account_email = module.kafka[0].cluster_service_account_email
    cluster_username              = module.kafka[0].cluster_username
    cluster_password              = module.kafka[0].cluster_password
    cluster_password_file_path    = module.kafka[0].cluster_password_file_path
    cluster_mechanism             = module.kafka[0].cluster_mechanism
    cluster_tls_enabled           = module.kafka[0].cluster_tls_enabled
  })
}

resource "google_secret_manager_secret" "runtime_redis_ca_cert" {
  secret_id = "${local.runtime_secret_prefix}-redis-ca-cert"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_redis_ca_cert" {
  secret = google_secret_manager_secret.runtime_redis_ca_cert.id
  secret_data = jsonencode({
    "server-ca.pem" = join("\n", compact([
      try(module.redis.redis.cache.ca_certificate, null),
      try(module.redis.redis.queue.ca_certificate, null),
      try(module.redis.redis.system.ca_certificate, null),
    ]))
  })
}
