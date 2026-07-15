# Flat chart-native env secret for ESO (paragon/<workspace>/env).
# Replaces the nested postgres/redis/storage JSON handoff used by the legacy
# paragon workspace. Infra-derived values are computed below; optional
# var.env_overrides can replace any of them; var.app_secrets
# (LICENSE, OAuth, SMTP, …) merges last. Written by module.secrets on every apply.

locals {
  argocd_postgres = module.postgres.rds
  argocd_redis    = module.redis.elasticache
  argocd_storage  = module.storage.s3

  argocd_cloud_storage_type = "S3"

  argocd_redis_cache = try(local.argocd_redis.cache, null)

  argocd_default_redis_url = local.argocd_redis_cache != null ? "${local.argocd_redis_cache.host}:${local.argocd_redis_cache.port}" : null

  # Infra ElastiCache exposes cache/queue/system and, when managed_sync_enabled,
  # managed_sync (the dedicated caching & workflows cluster). Map the workflow role
  # to managed_sync so WORKFLOW_REDIS_* targets that cluster instead of falling back
  # to cache. cache/queue/system map to themselves.
  argocd_redis_role_source = {
    cache    = "cache"
    queue    = "queue"
    system   = "system"
    workflow = "managed_sync"
  }

  argocd_redis_endpoint = {
    for role, source in local.argocd_redis_role_source :
    role => try(local.argocd_redis[source], local.argocd_redis_cache, null)
  }

  argocd_redis_cluster_enabled = {
    for role in keys(local.argocd_redis_endpoint) :
    role => try(local.argocd_redis_endpoint[role].cluster, false) ? "true" : "false"
  }

  argocd_redis_tls_enabled = {
    for role in keys(local.argocd_redis_endpoint) :
    role => try(local.argocd_redis_endpoint[role].ssl, false) ? "true" : "false"
  }

  argocd_redis_url = {
    for role in keys(local.argocd_redis_endpoint) :
    role => local.argocd_redis_endpoint[role] != null ? "${local.argocd_redis_endpoint[role].host}:${local.argocd_redis_endpoint[role].port}" : local.argocd_default_redis_url
  }

  # *_PUBLIC_URL / PARAGON_DOMAIN are chart envKeys owned by the paragon workspace
  # (`var.domain`). Do not derive them here from a second domain input — that can
  # desync Secrets Manager from Helm. Seed via env_overrides for GitOps-only flows.
  argocd_env_overrides = var.env_overrides != null ? var.env_overrides : {}

  argocd_postgres_env_prefixes = {
    CERBERUS   = "cerberus"
    EVENT_LOGS = "eventlogs"
    HERMES     = "hermes"
    PHEME      = "hermes"
    TRIGGERKIT = "triggerkit"
    ZEUS       = "zeus"
  }

  argocd_postgres_env = merge([
    for prefix, instance in local.argocd_postgres_env_prefixes : {
      "${prefix}_POSTGRES_HOST"     = try(local.argocd_postgres[instance].host, local.argocd_postgres.paragon.host)
      "${prefix}_POSTGRES_PORT"     = tostring(try(local.argocd_postgres[instance].port, local.argocd_postgres.paragon.port))
      "${prefix}_POSTGRES_USERNAME" = try(local.argocd_postgres[instance].user, local.argocd_postgres.paragon.user)
      "${prefix}_POSTGRES_PASSWORD" = try(local.argocd_postgres[instance].password, local.argocd_postgres.paragon.password)
      "${prefix}_POSTGRES_DATABASE" = try(local.argocd_postgres[instance].database, local.argocd_postgres.paragon.database)
    }
  ]...)

  argocd_s3_endpoint = "https://s3.${var.aws_region}.amazonaws.com"

  argocd_infra_env = {
    REDIS_URL = local.argocd_default_redis_url

    CACHE_REDIS_CLUSTER_ENABLED    = local.argocd_redis_cluster_enabled.cache
    CACHE_REDIS_TLS_ENABLED        = local.argocd_redis_tls_enabled.cache
    CACHE_REDIS_URL                = local.argocd_redis_url.cache
    QUEUE_REDIS_CLUSTER_ENABLED    = local.argocd_redis_cluster_enabled.queue
    QUEUE_REDIS_TLS_ENABLED        = local.argocd_redis_tls_enabled.queue
    QUEUE_REDIS_URL                = local.argocd_redis_url.queue
    SYSTEM_REDIS_CLUSTER_ENABLED   = local.argocd_redis_cluster_enabled.system
    SYSTEM_REDIS_TLS_ENABLED       = local.argocd_redis_tls_enabled.system
    SYSTEM_REDIS_URL               = local.argocd_redis_url.system
    WORKFLOW_REDIS_CLUSTER_ENABLED = local.argocd_redis_cluster_enabled.workflow
    WORKFLOW_REDIS_TLS_ENABLED     = local.argocd_redis_tls_enabled.workflow
    WORKFLOW_REDIS_URL             = local.argocd_redis_url.workflow

    CLOUD_STORAGE_COMPLIANCE_BUCKET = local.argocd_storage.auditlogs_bucket
    CLOUD_STORAGE_MICROSERVICE_PASS = local.argocd_storage.access_key_secret
    CLOUD_STORAGE_MICROSERVICE_USER = local.argocd_storage.access_key_id
    CLOUD_STORAGE_PUBLIC_BUCKET     = local.argocd_storage.public_bucket
    CLOUD_STORAGE_SYSTEM_BUCKET     = local.argocd_storage.private_bucket
    CLOUD_STORAGE_TYPE              = local.argocd_cloud_storage_type
    CLOUD_STORAGE_REGION            = var.aws_region
    CLOUD_STORAGE_PUBLIC_URL        = local.argocd_s3_endpoint
    CLOUD_STORAGE_PRIVATE_URL       = local.argocd_s3_endpoint
  }

  argocd_app_secret_overrides = var.app_secrets != null ? var.app_secrets : {}

  argocd_license_admin_auth = try(local.argocd_app_secret_overrides.LICENSE, null) != null ? {
    ADMIN_BASIC_AUTH_USERNAME = local.argocd_app_secret_overrides.LICENSE
    ADMIN_BASIC_AUTH_PASSWORD = local.argocd_app_secret_overrides.LICENSE
  } : {}

  env_config = {
    for key, value in merge(
      local.argocd_infra_env,
      local.argocd_postgres_env,
      local.argocd_env_overrides,
      local.argocd_license_admin_auth,
      local.argocd_app_secret_overrides,
    ) :
    key => tostring(value)
    if value != null && tostring(value) != ""
  }
}
