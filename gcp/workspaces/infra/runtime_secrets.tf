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

resource "google_secret_manager_secret" "runtime_monitoring" {
  secret_id = "${local.runtime_secret_prefix}-monitoring"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_monitoring" {
  secret      = google_secret_manager_secret.runtime_monitoring.id
  secret_data = jsonencode({
    pg_config = module.postgres.pg_config
  })
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
    logs_bucket         = module.storage.storage.logs_bucket
    auditlogs_bucket    = module.storage.storage.auditlogs_bucket
    # GCS (no MinIO): microservice creds are the same SA key as root.
    microservice_user = module.storage.storage.project_id
    microservice_pass = module.storage.storage.private_key
    root_user         = module.storage.storage.project_id
    root_password     = module.storage.storage.private_key
    service_account   = module.storage.storage.service_account
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
  count  = var.managed_sync_enabled ? 1 : 0
  secret = google_secret_manager_secret.runtime_kafka[0].id
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
    # Bundle every instance the redis module created; the set depends on
    # redis_multiple_instances and managed_sync_enabled.
    "server-ca.pem" = join("\n", compact([
      for name, instance in module.redis.redis : try(instance.ca_certificate, "")
    ]))
  })
}

resource "google_secret_manager_secret" "runtime_bastion" {
  count     = var.bastion_enabled ? 1 : 0
  secret_id = "${local.runtime_secret_prefix}-bastion"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_bastion" {
  count  = var.bastion_enabled ? 1 : 0
  secret = google_secret_manager_secret.runtime_bastion[0].id
  secret_data = jsonencode({
    public_dns  = module.bastion[0].connection.bastion_dns
    private_key = module.bastion[0].connection.private_key
  })
}

resource "google_secret_manager_secret" "runtime_cluster" {
  secret_id = "${local.runtime_secret_prefix}-cluster"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_cluster" {
  secret = google_secret_manager_secret.runtime_cluster.id
  secret_data = jsonencode({
    cluster_name = module.cluster.kubernetes.name
    location     = var.region
    k8s_version  = var.k8s_version
  })
}

# Agent OS secrets: app (mounted by every service), admin (migration Job only) and vendor
# (operator-owned API keys; Terraform creates the secret and never manages its contents).
resource "google_secret_manager_secret" "agent_os_app" {
  count     = var.agent_os_enabled ? 1 : 0
  secret_id = "${local.workspace}-agent-os-app"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "agent_os_app" {
  count       = var.agent_os_enabled ? 1 : 0
  secret      = google_secret_manager_secret.agent_os_app[0].id
  secret_data = jsonencode(local.agent_os_app_config)
}

resource "google_secret_manager_secret" "agent_os_admin" {
  count     = var.agent_os_enabled ? 1 : 0
  secret_id = "${local.workspace}-agent-os-admin"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "agent_os_admin" {
  count       = var.agent_os_enabled ? 1 : 0
  secret      = google_secret_manager_secret.agent_os_admin[0].id
  secret_data = jsonencode(local.agent_os_admin_config)
}

resource "google_secret_manager_secret" "agent_os_vendor" {
  count     = var.agent_os_enabled ? 1 : 0
  secret_id = "${local.workspace}-agent-os-vendor"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "agent_os_vendor" {
  count       = var.agent_os_enabled ? 1 : 0
  secret      = google_secret_manager_secret.agent_os_vendor[0].id
  secret_data = jsonencode({})

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret" "runtime_agent_os" {
  count     = var.agent_os_enabled ? 1 : 0
  secret_id = "${local.runtime_secret_prefix}-agent-os"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "runtime_agent_os" {
  count  = var.agent_os_enabled ? 1 : 0
  secret = google_secret_manager_secret.runtime_agent_os[0].id
  secret_data = jsonencode({
    app             = google_secret_manager_secret.agent_os_app[0].secret_id
    admin           = google_secret_manager_secret.agent_os_admin[0].secret_id
    vendor          = google_secret_manager_secret.agent_os_vendor[0].secret_id
    bucket          = module.storage.storage.agent_os_bucket
    service_account = module.storage.storage.agent_os_service_account
  })
}

# Agent OS app/admin secret payloads, composed from the postgres, redis, storage and kafka
# modules and stored in Secret Manager. Service pods only ever receive the app payload.

locals {
  agent_os_db    = module.postgres.agent_os
  agent_os_cache = module.redis.agent_os
  agent_os_kafka = one(module.kafka)

  agent_os_app_config = var.agent_os_enabled ? {
    CONTEXT_POSTGRES_HOST        = local.agent_os_db.host
    CONTEXT_POSTGRES_PORT        = tostring(local.agent_os_db.port)
    CONTEXT_POSTGRES_DATABASE    = local.agent_os_db.databases.context.database
    CONTEXT_POSTGRES_USERNAME    = local.agent_os_db.databases.context.user
    CONTEXT_POSTGRES_PASSWORD    = local.agent_os_db.databases.context.password
    CONTEXT_POSTGRES_SSL_ENABLED = "true"
    CONTEXT_POSTGRES_SSL_CA      = ""

    TOOLS_POSTGRES_HOST        = local.agent_os_db.host
    TOOLS_POSTGRES_PORT        = tostring(local.agent_os_db.port)
    TOOLS_POSTGRES_DATABASE    = local.agent_os_db.databases.tools.database
    TOOLS_POSTGRES_USERNAME    = local.agent_os_db.databases.tools.user
    TOOLS_POSTGRES_PASSWORD    = local.agent_os_db.databases.tools.password
    TOOLS_POSTGRES_SSL_ENABLED = "true"
    TOOLS_POSTGRES_SSL_CA      = ""

    REDIS_HOST = local.agent_os_cache.host
    REDIS_PORT = tostring(local.agent_os_cache.port)
    REDIS_URL  = "rediss://${local.agent_os_cache.host}:${local.agent_os_cache.port}"
    # IAM auth uses the workload GSA email as username. The short-lived access
    # token must be minted from Workload Identity and refreshed by the client.
    REDIS_USERNAME        = module.storage.storage.agent_os_service_account
    REDIS_PASSWORD        = ""
    REDIS_TLS_ENABLED     = tostring(local.agent_os_cache.ssl)
    REDIS_CLUSTER_ENABLED = tostring(local.agent_os_cache.cluster)
    REDIS_CA_CERT         = local.agent_os_cache.ca_certificate

    KAFKA_BROKER_URLS   = local.agent_os_kafka.cluster_bootstrap_brokers
    KAFKA_SASL_USERNAME = coalesce(local.agent_os_kafka.agent_os_cluster_username, local.agent_os_kafka.agent_os_service_account_email)
    # SASL/PLAIN carries the service account key JSON base64-encoded, same as
    # MANAGED_SYNC_KAFKA_SASL_PASSWORD in the Paragon helm config.
    KAFKA_SASL_PASSWORD  = local.agent_os_kafka.agent_os_cluster_password != null ? base64encode(local.agent_os_kafka.agent_os_cluster_password) : ""
    KAFKA_SASL_MECHANISM = local.agent_os_kafka.cluster_mechanism
    KAFKA_SSL_ENABLED    = tostring(local.agent_os_kafka.cluster_tls_enabled)

    # GCS bucket, addressed through the S3_* keys the Agent OS config slices expect.
    S3_BUCKET        = module.storage.storage.agent_os_bucket
    S3_PARSED_BUCKET = module.storage.storage.agent_os_bucket
    S3_PARSED_PREFIX = "parsed/"
    S3_INDEX_BUCKET  = module.storage.storage.agent_os_bucket
    S3_INDEX_AZ_ID   = ""
  } : null

  agent_os_admin_config = var.agent_os_enabled ? {
    ADMIN_POSTGRES_HOST        = local.agent_os_db.host
    ADMIN_POSTGRES_PORT        = tostring(local.agent_os_db.port)
    ADMIN_POSTGRES_DATABASE    = local.agent_os_db.admin_database
    ADMIN_POSTGRES_USERNAME    = local.agent_os_db.admin_user
    ADMIN_POSTGRES_PASSWORD    = local.agent_os_db.admin_password
    ADMIN_POSTGRES_SSL_ENABLED = "true"
    ADMIN_POSTGRES_SSL_CA      = ""
  } : null
}
