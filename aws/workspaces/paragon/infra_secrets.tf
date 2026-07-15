locals {
  infra_secret_names = {
    postgres = "paragon/${local.workspace}/postgres"
    redis    = "paragon/${local.workspace}/redis"
    storage  = "paragon/${local.workspace}/storage"
    kafka    = "paragon/${local.workspace}/kafka"
    cluster  = "paragon/${local.workspace}/cluster"
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

data "aws_secretsmanager_secret_version" "infra_cluster" {
  count     = local.use_legacy_infra_json ? 0 : 1
  secret_id = local.infra_secret_names.cluster
}

locals {
  provider_cluster = local.use_legacy_infra_json ? {} : jsondecode(
    # Cluster metadata (role names, SGs, flags) is not secret; nonsensitive avoids
    # Terraform rejecting sensitive nulls against object-typed module variables.
    nonsensitive(data.aws_secretsmanager_secret_version.infra_cluster[0].secret_string)
  )

  provider_infra_vars = merge(
    {
      workspace               = { value = local.workspace }
      cluster_name            = { value = try(local.provider_cluster.cluster_name, local.cluster_name) }
      logs_bucket             = { value = local.logs_bucket }
      auditlogs_bucket        = { value = local.auditlogs_bucket }
      postgres                = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_postgres[0].secret_string) }
      redis                   = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_redis[0].secret_string) }
      storage                 = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_storage[0].secret_string) }
      enable_karpenter        = { value = try(local.provider_cluster.enable_karpenter, false) }
      enable_legacy_mng_pools = { value = try(local.provider_cluster.enable_legacy_mng_pools, true) }
      k8s_version             = { value = try(local.provider_cluster.k8s_version, var.k8s_version) }
      karpenter               = { value = try(local.provider_cluster.karpenter, null) }
    },
    var.managed_sync_enabled ? {
      kafka = { value = jsondecode(data.aws_secretsmanager_secret_version.infra_kafka[0].secret_string) }
    } : {}
  )

  infra_vars = local.use_legacy_infra_json ? local.legacy_infra_vars : local.provider_infra_vars
}
