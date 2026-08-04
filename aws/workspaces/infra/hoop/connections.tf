locals {
  connection_prefix      = coalesce(var.hoop_agent_name, var.organization)
  connection_environment = var.customer_facing ? "prod" : "staging"
  default_access_groups  = var.customer_facing ? var.restricted_access_groups : concat(var.restricted_access_groups, var.all_access_groups)

  postgres_connections = {
    for database, config in var.infra_vars.postgres.value :
    "postgres-${database}" => {
      name    = length(var.infra_vars.postgres.value) == 1 ? "${local.connection_prefix}-postgres-db" : "${local.connection_prefix}-${database}-db"
      type    = "database"
      subtype = "postgres"
      command = null
      secrets = {
        "envvar:HOST"    = config.host
        "envvar:PORT"    = tostring(config.port)
        "envvar:USER"    = config.user
        "envvar:PASS"    = config.password
        "envvar:DB"      = config.database
        "envvar:SSLMODE" = try(config.sslmode, "disable")
      }
      access_mode_runbooks = "enabled"
      access_mode_exec     = "enabled"
      access_mode_connect  = "disabled"
      access_schema        = "enabled"
      guardrail_rules      = var.hoop_postgres_guardrail_rules
      reviewers            = null
      tags = {
        environment     = local.connection_environment
        customer_facing = var.customer_facing
        criticality     = "critical"
        access-level    = "private"
        impact          = "high"
        service-type    = "database"
        database-type   = "postgres"
        cloud           = "aws"
      }
    }
  }

  redis_connections = {
    for database, config in var.infra_vars.redis.value :
    "redis-${database}" => {
      name    = "${local.connection_prefix}-redis-${database}"
      type    = "custom"
      subtype = "redis"
      command = ["redis-cli", "-c", "-h", "$HOST", "-p", "$PORT", "-n", "$DB_NUMBER"]
      secrets = merge(
        {
          "envvar:HOST"      = config.host
          "envvar:PORT"      = tostring(config.port)
          "envvar:DB_NUMBER" = tostring(try(config.db_number, 0))
        },
        try(config.ssl, false) ? { "envvar:REDIS_TLS" = "1" } : {},
        try(config.ca_certificate, null) != null && try(config.ca_certificate, "") != "" ? { "envvar:REDIS_CA_CERT" = config.ca_certificate } : {},
        try(config.password, null) != null && try(config.password, "") != "" ? { "envvar:PASS" = config.password } : {},
      )
      access_mode_runbooks = "enabled"
      access_mode_exec     = "enabled"
      access_mode_connect  = "disabled"
      access_schema        = "disabled"
      guardrail_rules      = var.hoop_redis_guardrail_rules
      reviewers            = null
      tags = {
        environment     = local.connection_environment
        customer_facing = var.customer_facing
        criticality     = "critical"
        access-level    = "private"
        impact          = "high"
        service-type    = "cache"
        database-type   = "redis"
        cloud           = "aws"
      }
    }
  }

  application_connections = merge(
    {
      pgadmin = {
        name                 = "${local.connection_prefix}-pgadmin"
        type                 = "application"
        subtype              = "tcp"
        command              = ["bash"]
        secrets              = { "envvar:HOST" = "pgadmin.paragon", "envvar:PORT" = "5050" }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        guardrail_rules      = null
        reviewers            = var.customer_facing ? var.reviewers_access_groups : null
        tags                 = { environment = local.connection_environment, customer_facing = var.customer_facing, criticality = "critical", access-level = "private", impact = "high", service-type = "database", cloud = "aws" }
      }
      openobserve = {
        name                 = "${local.connection_prefix}-openobserve"
        type                 = "application"
        subtype              = "tcp"
        command              = ["bash"]
        secrets              = { "envvar:HOST" = "openobserve.paragon", "envvar:PORT" = "5080" }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        guardrail_rules      = null
        reviewers            = null
        tags                 = { environment = local.connection_environment, customer_facing = var.customer_facing, criticality = "normal", access-level = "private", impact = "low", service-type = "storage", cloud = "aws" }
      }
      redis-insight = {
        name                 = "${local.connection_prefix}-redis-insight"
        type                 = "application"
        subtype              = "tcp"
        command              = ["bash"]
        secrets              = { "envvar:HOST" = "redis-insight.paragon", "envvar:PORT" = "8500" }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        guardrail_rules      = null
        reviewers            = var.customer_facing ? var.reviewers_access_groups : null
        tags                 = { environment = local.connection_environment, customer_facing = var.customer_facing, criticality = "critical", access-level = "private", impact = "high", service-type = "database", cloud = "aws" }
      }
    },
    var.hoop_grafana_connection ? {
      grafana = {
        name                 = "${local.connection_prefix}-grafana"
        type                 = "application"
        subtype              = "tcp"
        command              = ["bash"]
        secrets              = { "envvar:HOST" = "grafana.paragon", "envvar:PORT" = "4500" }
        access_mode_runbooks = "enabled"
        access_mode_exec     = "enabled"
        access_mode_connect  = "enabled"
        access_schema        = "disabled"
        guardrail_rules      = null
        reviewers            = null
        tags                 = { environment = local.connection_environment, customer_facing = var.customer_facing, criticality = "normal", access-level = "private", impact = "low", service-type = "monitoring", cloud = "aws" }
      }
    } : {},
  )

  k8s_connections = length(var.k8s_connections) > 0 ? {
    for name, config in var.k8s_connections :
    "k8s-${name}" => {
      name    = "${local.connection_prefix}-k8s-${name}"
      type    = config.type
      subtype = try(config.subtype, null)
      command = config.command
      secrets = merge({
        "envvar:REMOTE_URL"           = config.remote_url
        "envvar:INSECURE"             = config.insecure
        "envvar:KUBECTL_NAMESPACE"    = config.namespace
        "envvar:HEADER_AUTHORIZATION" = "Bearer ${data.kubernetes_secret.hoop_cluster_admin_token.data["token"]}"
      }, config.secrets)
      access_mode_runbooks = config.access_mode_runbooks
      access_mode_exec     = config.access_mode_exec
      access_mode_connect  = config.access_mode_connect
      access_schema        = config.access_schema
      guardrail_rules      = length(config.guardrail_rules) > 0 ? config.guardrail_rules : null
      reviewers            = length(config.reviewers) > 0 ? config.reviewers : null
      tags                 = merge({ environment = local.connection_environment, customer_facing = var.customer_facing, criticality = "critical", access-level = "private", impact = "high", service-type = "compute", cloud = "aws", team = "platform-eng" }, config.tags)
      access_groups        = length(config.access_control_groups) > 0 ? config.access_control_groups : local.default_access_groups
    }
    } : {
    k8s-admin = {
      name    = "${local.connection_prefix}-k8s-admin"
      type    = "custom"
      subtype = null
      command = ["bash"]
      secrets = {
        "envvar:REMOTE_URL"           = "https://kubernetes.default.svc.cluster.local"
        "envvar:INSECURE"             = "true"
        "envvar:KUBECTL_NAMESPACE"    = var.namespace
        "envvar:HEADER_AUTHORIZATION" = "Bearer ${data.kubernetes_secret.hoop_cluster_admin_token.data["token"]}"
      }
      access_mode_runbooks = "enabled"
      access_mode_exec     = "enabled"
      access_mode_connect  = "enabled"
      access_schema        = "disabled"
      guardrail_rules      = null
      reviewers            = null
      tags                 = { environment = local.connection_environment, customer_facing = var.customer_facing, criticality = "critical", access-level = "private", impact = "high", service-type = "compute", cloud = "aws", team = "platform-eng" }
      access_groups        = local.default_access_groups
    }
  }

  custom_connection_defs = {
    for name, config in var.custom_connections :
    "custom-${name}" => {
      name                 = "${local.connection_prefix}-${name}"
      type                 = config.type
      subtype              = try(config.subtype, null)
      command              = try(config.command, null)
      secrets              = config.secrets
      access_mode_runbooks = config.access_mode_runbooks
      access_mode_exec     = config.access_mode_exec
      access_mode_connect  = config.access_mode_connect
      access_schema        = config.access_schema
      guardrail_rules      = length(config.guardrail_rules) > 0 ? config.guardrail_rules : null
      reviewers            = length(config.reviewers) > 0 ? config.reviewers : null
      tags                 = merge({ environment = local.connection_environment, customer_facing = var.customer_facing, cloud = try(config.tags.cloud, "aws") }, config.tags)
      access_groups        = length(config.access_control_groups) > 0 ? config.access_control_groups : local.default_access_groups
    }
  }

  all_connections = merge(local.redis_connections, local.application_connections, local.k8s_connections, local.custom_connection_defs)
  all_access_groups = merge(
    { for name in keys(local.redis_connections) : name => local.default_access_groups },
    { for name in keys(local.application_connections) : name => local.default_access_groups },
    { for name, config in local.k8s_connections : name => config.access_groups },
    { for name, config in local.custom_connection_defs : name => config.access_groups },
  )

  review_required_connections = {
    for name, config in local.all_connections : name => config
    if try(length(config.reviewers), 0) > 0
  }

  slack_enabled = var.hoop_slack_bot_token != null && var.hoop_slack_bot_token != "" && var.hoop_slack_app_token != null && var.hoop_slack_app_token != "" && length(var.hoop_slack_channel_ids) > 0
}

resource "hoop_connection" "all_connections" {
  for_each = toset(nonsensitive(keys(local.all_connections)))

  name                 = nonsensitive(local.all_connections[each.value].name)
  type                 = nonsensitive(local.all_connections[each.value].type)
  agent_id             = var.hoop_agent_id
  subtype              = nonsensitive(local.all_connections[each.value].subtype)
  command              = nonsensitive(local.all_connections[each.value].command)
  access_mode_runbooks = nonsensitive(local.all_connections[each.value].access_mode_runbooks)
  access_mode_exec     = nonsensitive(local.all_connections[each.value].access_mode_exec)
  access_mode_connect  = nonsensitive(local.all_connections[each.value].access_mode_connect)
  access_schema        = nonsensitive(local.all_connections[each.value].access_schema)
  guardrail_rules      = nonsensitive(local.all_connections[each.value].guardrail_rules)
  reviewers            = nonsensitive(local.all_connections[each.value].reviewers)
  secrets              = local.all_connections[each.value].secrets
  tags                 = nonsensitive(local.all_connections[each.value].tags)

  depends_on = [data.kubernetes_secret.hoop_cluster_admin_token]
}

resource "hoop_connection" "postgres_connections" {
  for_each = toset(nonsensitive(keys(local.postgres_connections)))

  name                 = nonsensitive(local.postgres_connections[each.value].name)
  type                 = nonsensitive(local.postgres_connections[each.value].type)
  agent_id             = var.hoop_agent_id
  subtype              = nonsensitive(local.postgres_connections[each.value].subtype)
  command              = nonsensitive(local.postgres_connections[each.value].command)
  access_mode_runbooks = nonsensitive(local.postgres_connections[each.value].access_mode_runbooks)
  access_mode_exec     = nonsensitive(local.postgres_connections[each.value].access_mode_exec)
  access_mode_connect  = nonsensitive(local.postgres_connections[each.value].access_mode_connect)
  access_schema        = nonsensitive(local.postgres_connections[each.value].access_schema)
  guardrail_rules      = nonsensitive(local.postgres_connections[each.value].guardrail_rules)
  reviewers            = nonsensitive(local.postgres_connections[each.value].reviewers)
  secrets              = local.postgres_connections[each.value].secrets
  tags                 = nonsensitive(local.postgres_connections[each.value].tags)

  lifecycle {
    ignore_changes = [command]
  }

  depends_on = [data.kubernetes_secret.hoop_cluster_admin_token]
}

resource "hoop_plugin_connection" "all_connections_access_control" {
  for_each = { for name, groups in local.all_access_groups : name => nonsensitive(groups) }

  plugin_name   = "access_control"
  connection_id = hoop_connection.all_connections[each.key].id
  config        = each.value
}

resource "hoop_plugin_connection" "postgres_connections_access_control" {
  for_each = { for name in nonsensitive(keys(local.postgres_connections)) : name => nonsensitive(local.default_access_groups) }

  plugin_name   = "access_control"
  connection_id = hoop_connection.postgres_connections[each.key].id
  config        = each.value
}

resource "hoop_plugin_config" "slack" {
  count = nonsensitive(local.slack_enabled) ? 1 : 0

  plugin_name = "slack"
  config = {
    SLACK_BOT_TOKEN = var.hoop_slack_bot_token
    SLACK_APP_TOKEN = var.hoop_slack_app_token
  }
}

resource "hoop_plugin_connection" "slack" {
  for_each = nonsensitive(local.slack_enabled) ? toset(nonsensitive(keys(local.review_required_connections))) : toset([])

  plugin_name   = "slack"
  connection_id = hoop_connection.all_connections[each.key].id
  config        = var.hoop_slack_channel_ids

  depends_on = [hoop_plugin_config.slack]
}
