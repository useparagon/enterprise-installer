module "helm" {
  source = "./helm"

  cluster_name               = local.cluster_name
  docker_cfg_secret_name     = var.create_docker_pull_secret && length(azurerm_key_vault_secret.docker_cfg) > 0 ? azurerm_key_vault_secret.docker_cfg[0].name : null
  docker_pull_secret_name    = var.docker_pull_secret_name
  create_docker_pull_secret  = var.create_docker_pull_secret
  env_secret_name            = azurerm_key_vault_secret.env.name
  external_secrets_client_id = azurerm_user_assigned_identity.external_secrets.client_id
  external_secrets_tenant_id = data.azurerm_client_config.current.tenant_id
  external_secrets_workload_identity_ready = sha256(join(":", [
    azurerm_key_vault_access_policy.external_secrets.id,
    time_sleep.external_secrets_federation.id,
  ]))
  legacy_external_secrets_client_id     = var.azure_client_id
  legacy_external_secrets_client_secret = var.azure_client_secret
  feature_flags_content                 = local.feature_flags_content
  flipt_options                         = local.flipt_options
  helm_values                           = local.helm_values_public
  secrets_revision = sha256(jsonencode({
    env             = azurerm_key_vault_secret.env.version
    docker_cfg      = length(azurerm_key_vault_secret.docker_cfg) > 0 ? azurerm_key_vault_secret.docker_cfg[0].version : null
    managed_sync    = var.managed_sync_enabled ? azurerm_key_vault_secret.managed_sync[0].version : null
    openobserve     = azurerm_key_vault_secret.openobserve[0].version
    agent_os_app    = var.agent_os_enabled ? azurerm_key_vault_secret.agent_os_app[0].version : null
    agent_os_admin  = var.agent_os_enabled ? azurerm_key_vault_secret.agent_os_admin[0].version : null
    agent_os_broker = var.agent_os_enabled ? azurerm_key_vault_secret.agent_os_broker[0].version : null
    agent_os_vendor = var.agent_os_enabled ? azurerm_key_vault_secret.agent_os_vendor[0].version : null
  }))
  ingress_scheme                       = var.ingress_scheme
  path_based_routing_enabled           = var.path_based_routing_enabled
  nginx_public                         = local.nginx_public
  agc_active                           = local.agc_active
  agc_direct                           = local.agc_direct
  agc_subnet_cidr                      = try(local.infra_vars.network.value.agc_subnet_cidr, null)
  key_vault_name                       = data.azurerm_key_vault.paragon.name
  k8s_version                          = var.k8s_version
  logs_bucket                          = local.logs_bucket
  managed_sync_enabled                 = var.managed_sync_enabled
  managed_sync_secret_name             = var.managed_sync_enabled ? azurerm_key_vault_secret.managed_sync[0].name : null
  managed_sync_version                 = var.managed_sync_version
  agent_os_enabled                     = var.agent_os_enabled
  domain                               = var.domain
  agent_os_version                     = var.agent_os_version
  agent_os_helm_repository             = var.agent_os_helm_repository
  agent_os_helm_values                 = var.agent_os_helm_values
  agent_os_file_values                 = try(local.helm_vars.agentOs.values, {})
  agent_os_workload_identity_client_id = var.agent_os_enabled ? azurerm_user_assigned_identity.agent_os[0].client_id : null
  agent_os_workload_identity_ready = var.agent_os_enabled ? sha256(join(":", [
    azurerm_federated_identity_credential.agent_os[0].id,
    azurerm_role_assignment.agent_os_storage[0].id,
  ])) : null
  paragon_helm_repository  = var.paragon_helm_repository
  microservices            = local.microservices
  monitor_version          = local.monitor_version
  monitors                 = local.monitors
  monitors_enabled         = var.monitors_enabled
  openobserve_email        = local.openobserve_email
  openobserve_password     = local.openobserve_password
  openobserve_secret_name  = azurerm_key_vault_secret.openobserve[0].name
  public_microservices     = local.public_microservices
  public_monitors          = local.public_monitors
  public_services          = local.public_services
  restrict_public_exposure = local.restrict_public_exposure
  resource_group           = local.infra_vars.resource_group.value
  workspace                = local.workspace
}

module "managed_sync_config" {
  source = "./helm-config"
  count  = var.managed_sync_enabled ? 1 : 0

  base_helm_values = local.helm_vars
  infra_values     = local.infra_vars
  domain           = var.domain
  microservices    = local.microservices
}

module "hoop" {
  source = "./hoop"

  workspace                     = local.workspace
  organization                  = var.organization
  hoop_agent_name               = var.hoop_agent_name
  hoop_enabled                  = var.hoop_enabled
  hoop_version                  = var.hoop_version
  hoop_image_repository         = var.hoop_image_repository
  hoop_image_tag                = var.hoop_image_tag
  hoop_key                      = var.hoop_key
  hoop_agent_id                 = var.hoop_agent_id
  all_access_groups             = var.hoop_all_access_groups
  restricted_access_groups      = var.hoop_restricted_access_groups
  reviewers_access_groups       = var.hoop_reviewers_access_groups
  hoop_postgres_guardrail_rules = var.hoop_postgres_guardrail_rules
  hoop_redis_guardrail_rules    = var.hoop_redis_guardrail_rules
  customer_facing               = var.customer_facing
  namespace_paragon             = module.helm.namespace_paragon
  azure_subscription_id         = var.azure_subscription_id
  azure_tenant_id               = coalesce(var.azure_tenant_id, data.azurerm_client_config.current.tenant_id)
  oidc_issuer_url               = try(data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url, "")
  resource_group = {
    name     = local.infra_vars.resource_group.value.name
    location = local.infra_vars.resource_group.value.location
  }
  custom_connections = var.hoop_custom_connections
  k8s_connections    = var.hoop_k8s_connections
  infra_vars = {
    postgres      = try(local.infra_vars.postgres, null)
    redis         = try(local.infra_vars.redis, null)
    redis_managed = try(local.infra_vars.redis_managed, null)
  }
}

module "monitors" {
  source = "./monitors"
  count  = var.monitors_enabled ? 1 : 0

  grafana_admin_email    = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_USER"], null)
  grafana_admin_password = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_PASSWORD"], null)
  pgadmin_admin_email    = try(local.helm_vars.global.env["MONITOR_PGADMIN_EMAIL"], null)
  pgadmin_admin_password = try(local.helm_vars.global.env["MONITOR_PGADMIN_PASSWORD"], null)
}

module "uptime" {
  source = "./uptime"

  uptime_api_token = var.uptime_api_token
  uptime_company   = coalesce(var.uptime_company, var.organization)
  microservices    = local.uptime_services
}

locals {
  # Public front door for DNS. Records stay on nginx until agc_dns_cutover.
  dns_ingress_target = local.dns_target_agc ? module.agc.fqdn : module.helm.load_balancer
  # Low TTL while AGC is enabled but records still point at nginx, so the cutover
  # (and a rollback to nginx) propagates quickly.
  dns_record_ttl = local.agc_active && !local.dns_target_agc ? 60 : 300

  dns_public_services = merge(
    {
      for name, cfg in local.public_services :
      name => cfg
      # Path-routed external proxy hosts are not in the Paragon zone. Only the
      # shared path-routing.<domain> origin is published for those services.
      if try(cfg.path_prefix, "") == ""
    },
    var.path_based_routing_enabled && (
      length(local.path_routed_public_prefixes) > 0 ||
      (var.agent_os_enabled && local.agent_os_path_prefix != "")
      ) ? {
      "path-routing" = {
        port        = 443
        public_url  = "https://${local.path_routing_origin_host}"
        origin_host = local.path_routing_origin_host
      }
    } : {},
  )

  # Match helm/helm.tf subchart_values: every microservice is forced on, then
  # helm_values.subchart overrides (later merge wins). Do NOT read the chart's
  # values.yaml defaults — those keep cache-replay/health-checker off while Helm
  # still deploys them, which would omit AGC HTTPS listeners for live hosts.
  onprem_subchart_enabled = merge(
    { for name in keys(local.microservices) : name => { enabled = true } },
    try(local.helm_vars.subchart, {}),
    local.restrict_public_exposure ? { health-checker = { enabled = true } } : {},
  )

  # AGC routes are normalized at the workspace boundary. Path-routed services
  # share path-routing.<domain> TLS while HTTPRoute matching stays hostless.
  agc_public_routes = {
    for name, cfg in local.public_services :
    name => {
      host             = cfg.origin_host
      path_prefix      = try(cfg.path_prefix, "")
      healthcheck_path = try(cfg.healthcheck_path, "/healthz")
      port             = cfg.port
    }
    if try(local.onprem_subchart_enabled[name].enabled, true) && !(
      name == "api-sync" && try(cfg.path_prefix, "") != ""
    )
  }

  # Managed Sync keeps one host listener until its public URL carries a path.
  # The chart does not strip that prefix; the Managed Sync team owns that.
  managed_sync_path_routes = [
    { path = "/api/sync-projects", service = "api-project", port = try(local.microservices["api-project"].port, 1804) },
    { path = "/api/catalog", service = "api-project", port = try(local.microservices["api-project"].port, 1804) },
    { path = "/api/syncs", service = "api-sync", port = try(local.microservices["api-sync"].port, 1800) },
    { path = "/api/permissions", service = "api-sync", port = try(local.microservices["api-sync"].port, 1800) },
    { path = "/api/webhooks", service = "api-webhook", port = try(local.microservices["api-webhook"].port, 1809) },
    { path = "/worker/sync", service = "worker-sync", port = try(local.microservices["worker-sync"].port, 1802) },
    { path = "/worker/history/sync", service = "worker-history-sync", port = try(local.microservices["worker-history-sync"].port, 1807) },
    { path = "/", service = "api-sync", port = try(local.microservices["api-sync"].port, 1800) },
  ]

  managed_sync_agc_routes = (
    var.managed_sync_enabled && local.agc_direct &&
    try(local.public_microservices["api-sync"].path_prefix, "") != ""
    ) ? {
    "api-sync" = {
      host             = local.public_microservices["api-sync"].origin_host
      port             = local.public_microservices["api-sync"].port
      path_prefix      = local.public_microservices["api-sync"].path_prefix
      healthcheck_path = "/healthz"
      routes = [
        for route in local.managed_sync_path_routes : merge(route, {
          path = route.path == "/" ? local.public_microservices["api-sync"].path_prefix : "${local.public_microservices["api-sync"].path_prefix}${route.path}"
        })
      ]
    }
  } : {}
}

module "dns" {
  source = "./dns"

  enabled              = local.cloudflare_dns_enabled
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  ingress_loadbalancer = local.dns_ingress_target
  public_services      = var.ingress_scheme == "internal" ? {} : local.dns_public_services
  ttl                  = local.dns_record_ttl
}

module "dns_zone" {
  source = "./dns-zone"

  enabled              = local.azure_dns_enabled
  resource_group_name  = local.infra_vars.resource_group.value.name
  domain               = var.domain
  dns_provider         = local.has_cloudflare_credentials ? "cloudflare" : "none"
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
}

module "dns_records" {
  source = "./dns-records"
  count  = local.azure_dns_enabled ? 1 : 0

  enabled              = true
  zone_name            = module.dns_zone.zone_name
  resource_group_name  = module.dns_zone.resource_group_name
  domain               = var.domain
  ingress_loadbalancer = local.dns_ingress_target
  public_services      = var.ingress_scheme == "internal" ? {} : local.dns_public_services
  record_ttl           = local.dns_record_ttl
}

module "waf" {
  source = "./waf"
  count  = local.waf_active ? 1 : 0

  workspace                      = local.workspace
  resource_group_name            = local.infra_vars.resource_group.value.name
  location                       = local.infra_vars.resource_group.value.location
  tags                           = local.default_tags
  waf_mode                       = var.waf_mode
  waf_ip_whitelist               = var.waf_ip_whitelist
  waf_ip_blacklist               = var.waf_ip_blacklist
  waf_rate_limit_global          = var.waf_rate_limit_global
  waf_rate_limit_global_duration = var.waf_rate_limit_global_duration
  waf_rate_limit_paths           = var.waf_rate_limit_paths
  waf_rate_limit_path_duration   = var.waf_rate_limit_path_duration
  waf_rate_limit_group_by        = var.waf_rate_limit_group_by
  waf_max_request_body_size_kb   = var.waf_max_request_body_size_kb
  waf_file_upload_limit_mb       = var.waf_file_upload_limit_mb
  waf_managed_rule_sets          = var.waf_managed_rule_sets
}

resource "terraform_data" "agc_requires_subnet" {
  count = local.agc_active ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        try(local.infra_vars.network.value.agc_subnet_id, null) != null &&
        try(local.infra_vars.network.value.agc_subnet_cidr, null) != null
      )
      error_message = "agc_enabled=true requires infra agc_subnet_enabled=true first (AGC association subnet ID and CIDR). Apply the infra workspace before enabling AGC."
    }
  }
}

# AGC module; gated by `enabled` (owns its own kube providers like helm).
module "agc" {
  source = "./agc"

  enabled                    = local.agc_active
  direct_routing             = var.agc_direct_routing
  path_based_routing_enabled = var.path_based_routing_enabled
  workspace                  = local.workspace
  resource_group_name        = local.infra_vars.resource_group.value.name
  location                   = local.infra_vars.resource_group.value.location
  cluster_name               = local.cluster_name
  subnet_id                  = try(local.infra_vars.network.value.agc_subnet_id, null)
  namespace                  = module.helm.namespace_paragon.metadata[0].name
  public_services            = merge(local.agc_public_routes, local.agent_os_agc_routes, local.managed_sync_agc_routes)
  waf_enabled                = local.waf_active
  waf_policy_id              = local.waf_active ? module.waf[0].policy_id : null
  alb_controller_version     = var.agc_alb_controller_version
  tags                       = local.default_tags
}

locals {
  # AGC direct routing: one HTTPS listener, path-specific backends (nginx Ingress is off).
  agent_os_agc_routes = var.agent_os_enabled && local.agc_direct ? {
    agentos = {
      host             = local.agent_os_host
      port             = local.agent_os_port
      path_prefix      = var.path_based_routing_enabled ? local.agent_os_path_prefix : ""
      healthcheck_path = "/readyz"
      routes = [
        for route in [
          { path = "/api/context", service = "context-api", port = local.agent_os_port },
          { path = "/api/tools", service = "tools-api", port = 3002 },
          ] : merge(route, {
            path = var.path_based_routing_enabled && local.agent_os_path_prefix != "" ? "${local.agent_os_path_prefix}${route.path}" : route.path
        })
      ]
    }
  } : {}
}
