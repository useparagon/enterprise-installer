locals {
  infra_secret_names = {
    postgres      = "${local.workspace}-postgres"
    redis         = "${local.workspace}-redis"
    storage       = "${local.workspace}-storage"
    kafka         = "${local.workspace}-kafka"
    redis_ca_cert = "${local.workspace}-redis-ca-cert"
  }
}

data "google_secret_manager_secret_version" "infra_postgres" {
  count   = local.use_legacy_infra_json ? 0 : 1
  project = local.gcp_project_id
  secret  = local.infra_secret_names.postgres
  version = "latest"
}

data "google_secret_manager_secret_version" "infra_redis" {
  count   = local.use_legacy_infra_json ? 0 : 1
  project = local.gcp_project_id
  secret  = local.infra_secret_names.redis
  version = "latest"
}

data "google_secret_manager_secret_version" "infra_storage" {
  count   = local.use_legacy_infra_json ? 0 : 1
  project = local.gcp_project_id
  secret  = local.infra_secret_names.storage
  version = "latest"
}

data "google_secret_manager_secret_version" "infra_kafka" {
  count   = local.use_legacy_infra_json ? 0 : (var.managed_sync_enabled ? 1 : 0)
  project = local.gcp_project_id
  secret  = local.infra_secret_names.kafka
  version = "latest"
}

locals {
  provider_infra_vars = merge(
    {
      workspace        = { value = local.workspace }
      cluster_name     = { value = local.cluster_name }
      logs_bucket      = { value = local.logs_bucket }
      auditlogs_bucket = { value = local.auditlogs_bucket }
      postgres         = { value = jsondecode(data.google_secret_manager_secret_version.infra_postgres[0].secret_data) }
      redis            = { value = jsondecode(data.google_secret_manager_secret_version.infra_redis[0].secret_data) }
      minio            = { value = jsondecode(data.google_secret_manager_secret_version.infra_storage[0].secret_data) }
    },
    var.managed_sync_enabled ? {
      kafka = { value = jsondecode(data.google_secret_manager_secret_version.infra_kafka[0].secret_data) }
    } : {}
  )

  infra_vars = local.use_legacy_infra_json ? local.legacy_infra_vars : local.provider_infra_vars
}
