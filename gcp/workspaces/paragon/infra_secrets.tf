locals {
  infra_secret_names = {
    postgres      = "${local.workspace}-postgres"
    monitoring    = "${local.workspace}-monitoring"
    redis         = "${local.workspace}-redis"
    storage       = "${local.workspace}-storage"
    kafka         = "${local.workspace}-kafka"
    redis_ca_cert = "${local.workspace}-redis-ca-cert"
    cluster       = "${local.workspace}-cluster"
  }
}

data "google_secret_manager_secret_version" "infra_postgres" {
  count   = local.use_legacy_infra_json ? 0 : 1
  project = local.gcp_project_id
  secret  = local.infra_secret_names.postgres
  version = "latest"
}

# Optional: infra creates this secret in the same change as pg_config. Missing
# (paragon applied first, or pre-PARA-25692 infra) must not fail plan/apply.
data "google_secret_manager_secrets" "infra_monitoring" {
  count   = local.use_legacy_infra_json ? 0 : 1
  project = local.gcp_project_id
  filter  = "name:${local.infra_secret_names.monitoring}"
}

locals {
  infra_monitoring_secret_exists = anytrue([
    for s in try(data.google_secret_manager_secrets.infra_monitoring[0].secrets, []) :
    endswith(s.name, "/secrets/${local.infra_secret_names.monitoring}")
  ])
}

data "google_secret_manager_secret_version" "infra_monitoring" {
  count   = (!local.use_legacy_infra_json && local.infra_monitoring_secret_exists) ? 1 : 0
  project = local.gcp_project_id
  secret  = local.infra_secret_names.monitoring
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

data "google_secret_manager_secret_version" "infra_cluster" {
  count   = local.use_legacy_infra_json ? 0 : 1
  project = local.gcp_project_id
  secret  = local.infra_secret_names.cluster
  version = "latest"
}

locals {
  # Cluster metadata is not sensitive; nonsensitive avoids propagating secret
  # sensitivity into providers/modules that take a plain cluster name.
  provider_cluster = local.use_legacy_infra_json ? {} : jsondecode(
    nonsensitive(data.google_secret_manager_secret_version.infra_cluster[0].secret_data)
  )

  provider_infra_vars = merge(
    {
      workspace        = { value = local.workspace }
      cluster_name     = { value = try(local.provider_cluster.cluster_name, local.cluster_name) }
      logs_bucket      = { value = local.logs_bucket }
      auditlogs_bucket = { value = local.auditlogs_bucket }
      postgres         = { value = jsondecode(data.google_secret_manager_secret_version.infra_postgres[0].secret_data) }
      monitoring = {
        value = (
          length(data.google_secret_manager_secret_version.infra_monitoring) > 0
          ? jsondecode(nonsensitive(data.google_secret_manager_secret_version.infra_monitoring[0].secret_data))
          : {}
        )
      }
      redis            = { value = jsondecode(data.google_secret_manager_secret_version.infra_redis[0].secret_data) }
      storage          = { value = jsondecode(data.google_secret_manager_secret_version.infra_storage[0].secret_data) }
      k8s_version      = { value = try(local.provider_cluster.k8s_version, null) }
    },
    var.managed_sync_enabled ? {
      kafka = { value = jsondecode(data.google_secret_manager_secret_version.infra_kafka[0].secret_data) }
    } : {}
  )

  infra_vars = local.use_legacy_infra_json ? local.legacy_infra_vars : local.provider_infra_vars
}
