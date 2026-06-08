locals {
  infra_secret_names = {
    postgres = "paragon/${local.workspace}/postgres"
    redis    = "paragon/${local.workspace}/redis"
    storage  = "paragon/${local.workspace}/storage"
    kafka    = "paragon/${local.workspace}/kafka"
  }
}

data "aws_secretsmanager_secret_version" "infra_postgres" {
  count     = local.use_legacy_infra_json ? 0 : 1
  secret_id = local.infra_secret_names.postgres
}

data "aws_secretsmanager_secret_version" "infra_redis" {
  count     = local.use_legacy_infra_json ? 0 : 1
  secret_id = local.infra_secret_names.redis
}

data "aws_secretsmanager_secret_version" "infra_storage" {
  count     = local.use_legacy_infra_json ? 0 : 1
  secret_id = local.infra_secret_names.storage
}

data "aws_secretsmanager_secret_version" "infra_kafka" {
  count     = local.use_legacy_infra_json ? 0 : (var.managed_sync_enabled ? 1 : 0)
  secret_id = local.infra_secret_names.kafka
}

locals {
  provider_infra_vars = merge(
    {
      workspace        = { value = local.workspace }
      cluster_name     = { value = local.cluster_name }
      logs_bucket      = { value = local.logs_bucket }
      auditlogs_bucket = { value = local.auditlogs_bucket }
      postgres         = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_postgres[0].secret_string) }
      redis            = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_redis[0].secret_string) }
      minio            = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_storage[0].secret_string) }
    },
    var.managed_sync_enabled ? {
      kafka = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_kafka[0].secret_string) }
    } : {}
  )

  infra_vars = local.use_legacy_infra_json ? local.legacy_infra_vars : local.provider_infra_vars
}
