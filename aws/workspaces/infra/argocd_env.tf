# Flat chart-native env secret for ESO (paragon/<workspace>/env).
# Replaces the nested postgres/redis/storage JSON handoff used by the legacy
# paragon workspace. Infra-derived values are computed below; optional
# var.argocd_env_overrides can replace any of them; var.argocd_app_secrets
# (LICENSE, OAuth, SMTP, …) merges last. Written by module.secrets on every apply.

locals {
  argocd_domain = var.paragon_domain != null ? trimspace(var.paragon_domain) : ""

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

  # Default https://<subdomain>.<domain> for each public service. Omitted when
  # paragon_domain is unset (lint/plan without domain). Override any computed
  # key via var.argocd_env_overrides (e.g. ACCOUNT_PUBLIC_URL, CERBERUS_POSTGRES_PORT).
  argocd_public_url_subdomains = {
    ACCOUNT_PUBLIC_URL            = "account"
    API_TRIGGERKIT_PUBLIC_URL     = "api-triggerkit"
    CACHE_REPLAY_PUBLIC_URL       = "cache-replay"
    CERBERUS_PUBLIC_URL           = "cerberus"
    CONNECT_PUBLIC_URL            = "connect"
    DASHBOARD_PUBLIC_URL          = "dashboard"
    HADES_PUBLIC_URL              = "hades"
    HEALTH_CHECKER_PUBLIC_URL     = "health-checker"
    HERMES_PUBLIC_URL             = "hermes"
    PASSPORT_PUBLIC_URL           = "passport"
    PHEME_PUBLIC_URL              = "pheme"
    RELEASE_PUBLIC_URL            = "release"
    ZEUS_PUBLIC_URL               = "zeus"
    WORKER_ACTIONKIT_PUBLIC_URL   = "worker-actionkit"
    WORKER_ACTIONS_PUBLIC_URL     = "worker-actions"
    WORKER_AUDIT_LOGS_PUBLIC_URL  = "worker-auditlogs"
    WORKER_CREDENTIALS_PUBLIC_URL = "worker-credentials"
    WORKER_CRONS_PUBLIC_URL       = "worker-crons"
    WORKER_DEPLOYMENTS_PUBLIC_URL = "worker-deployments"
    WORKER_EVENT_LOGS_PUBLIC_URL  = "worker-eventlogs"
    WORKER_PROXY_PUBLIC_URL       = "worker-proxy"
    WORKER_TRIGGERKIT_PUBLIC_URL  = "worker-triggerkit"
    WORKER_TRIGGERS_PUBLIC_URL    = "worker-triggers"
    WORKER_WORKFLOWS_PUBLIC_URL   = "worker-workflows"
  }

  argocd_public_url_defaults = local.argocd_domain != "" ? {
    for env_key, subdomain in local.argocd_public_url_subdomains :
    env_key => "https://${subdomain}.${local.argocd_domain}"
  } : {}

  argocd_env_overrides = var.argocd_env_overrides != null ? var.argocd_env_overrides : {}

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

  argocd_domain_env = local.argocd_domain != "" ? {
    PARAGON_DOMAIN               = local.argocd_domain
    PUBLIC_UPLOAD_PROXY_BASE_URL = "https://zeus.${local.argocd_domain}/public-upload-proxy"
  } : {}

  argocd_infra_env = merge(local.argocd_domain_env, {
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
  })

  argocd_app_secret_overrides = var.argocd_app_secrets != null ? var.argocd_app_secrets : {}

  argocd_license_admin_auth = try(local.argocd_app_secret_overrides.LICENSE, null) != null ? {
    ADMIN_BASIC_AUTH_USERNAME = local.argocd_app_secret_overrides.LICENSE
    ADMIN_BASIC_AUTH_PASSWORD = local.argocd_app_secret_overrides.LICENSE
  } : {}

  argocd_env_secret = {
    for key, value in merge(
      local.argocd_infra_env,
      local.argocd_postgres_env,
      local.argocd_public_url_defaults,
      local.argocd_env_overrides,
      local.argocd_license_admin_auth,
      local.argocd_app_secret_overrides,
    ) :
    key => tostring(value)
    if value != null && tostring(value) != ""
  }
}
