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

  # Map chart Redis roles to ElastiCache instances. workflow shares cache —
  # there is no dedicated workflow cluster (see charts/example.yaml).
  argocd_redis_role_source = {
    cache    = "cache"
    queue    = "queue"
    system   = "system"
    workflow = "cache"
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

# Agent OS app/admin secret payloads, composed from the postgres, redis, storage and kafka
# modules and written by module.secrets. Service pods only ever receive the app payload.

locals {
  agent_os_db    = module.postgres.agent_os
  agent_os_cache = module.redis.agent_os
  agent_os_kafka = one(module.kafka)

  agent_os_s3_parsed_prefix = "parsed/"

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

    REDIS_HOST            = local.agent_os_cache.host
    REDIS_PORT            = tostring(local.agent_os_cache.port)
    REDIS_URL             = "rediss://:${urlencode(local.agent_os_cache.password)}@${local.agent_os_cache.host}:${local.agent_os_cache.port}"
    REDIS_PASSWORD        = local.agent_os_cache.password
    REDIS_TLS_ENABLED     = tostring(local.agent_os_cache.ssl)
    REDIS_CLUSTER_ENABLED = tostring(local.agent_os_cache.cluster)

    KAFKA_BROKER_URLS    = local.agent_os_kafka.cluster_bootstrap_brokers_sasl_scram
    KAFKA_SASL_USERNAME  = local.agent_os_kafka.agent_os_kafka_credentials.username
    KAFKA_SASL_PASSWORD  = local.agent_os_kafka.agent_os_kafka_credentials.password
    KAFKA_SASL_MECHANISM = local.agent_os_kafka.agent_os_kafka_credentials.mechanism
    KAFKA_SSL_ENABLED    = tostring(local.agent_os_kafka.cluster_tls_enabled)

    AWS_REGION       = var.aws_region
    S3_BUCKET        = module.storage.s3.agent_os_bucket
    S3_PARSED_BUCKET = module.storage.s3.agent_os_bucket
    S3_PARSED_PREFIX = local.agent_os_s3_parsed_prefix
    S3_INDEX_BUCKET  = module.storage.s3.agent_os_bucket
    # S3 Express is not provisioned on enterprise, so the index bucket has no AZ affinity.
    S3_INDEX_AZ_ID = ""
  } : null

  agent_os_admin_config = var.agent_os_enabled ? {
    ADMIN_POSTGRES_HOST        = local.agent_os_db.host
    ADMIN_POSTGRES_PORT        = tostring(local.agent_os_db.port)
    ADMIN_POSTGRES_DATABASE    = local.agent_os_db.admin_database
    ADMIN_POSTGRES_USERNAME    = local.agent_os_db.admin_user
    ADMIN_POSTGRES_PASSWORD    = local.agent_os_db.admin_password
    ADMIN_POSTGRES_SSL_ENABLED = "true"
    ADMIN_POSTGRES_SSL_CA      = ""

    ADMIN_KAFKA_BROKER_URLS    = local.agent_os_kafka.cluster_bootstrap_brokers_sasl_scram
    ADMIN_KAFKA_SASL_USERNAME  = local.agent_os_kafka.acl_admin_kafka_credentials.username
    ADMIN_KAFKA_SASL_PASSWORD  = local.agent_os_kafka.acl_admin_kafka_credentials.password
    ADMIN_KAFKA_SASL_MECHANISM = local.agent_os_kafka.acl_admin_kafka_credentials.mechanism
    ADMIN_KAFKA_SSL_ENABLED    = tostring(local.agent_os_kafka.cluster_tls_enabled)

    KAFKA_PRINCIPAL_ACL_ADMIN    = local.agent_os_kafka.acl_admin_kafka_credentials.username
    KAFKA_PRINCIPAL_AGENT_OS     = local.agent_os_kafka.agent_os_kafka_credentials.username
    KAFKA_PRINCIPAL_MANAGED_SYNC = local.agent_os_kafka.kafka_credentials.username

    KAFKA_TOPIC_PARTITIONS          = "3"
    KAFKA_TOPIC_REPLICATION_FACTOR  = tostring(ceil(var.msk_kafka_num_broker_nodes / 2))
    KAFKA_TOPIC_MIN_INSYNC_REPLICAS = tostring(ceil(var.msk_kafka_num_broker_nodes / 2))
  } : null
}
