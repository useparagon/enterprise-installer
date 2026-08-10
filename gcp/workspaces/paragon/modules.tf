module "managed_sync_config" {
  source = "./helm-config"
  count  = var.managed_sync_enabled ? 1 : 0

  base_helm_values   = local.helm_vars
  domain             = var.domain
  infra_values       = local.infra_vars
  gcp_storage_sa_key = local.cloud_storage_type == "GCP" ? local.gcp_creds : null
  microservices = merge(local.microservices, {
    "api-sync" = {
      healthcheck_path = "/healthz"
      port             = 1800
      public_url       = "https://sync.${var.domain}"
    }
    "queue-exporter" = {
      healthcheck_path = "/healthz"
      port             = 1806
      public_url       = null
    }
  })
}

module "waf" {
  source = "./waf"
  count  = local.waf_active ? 1 : 0

  workspace                        = local.workspace
  waf_ip_whitelist                 = var.waf_ip_whitelist
  waf_ip_blacklist                 = var.waf_ip_blacklist
  waf_ip_blacklist_deny_status     = var.waf_ip_blacklist_deny_status
  waf_rate_limit_global            = var.waf_rate_limit_global
  waf_rate_limit_global_window_sec = var.waf_rate_limit_global_window_sec
  waf_rate_limit_paths             = var.waf_rate_limit_paths
  waf_rate_limit_path_window_sec   = var.waf_rate_limit_path_window_sec
  waf_rate_limit_options           = var.waf_rate_limit_options
  waf_preconfigured_rules          = var.waf_preconfigured_rules
  waf_custom_rules                 = var.waf_custom_rules
  waf_advanced_options             = var.waf_advanced_options
}

module "helm" {
  source = "./helm"

  cluster_name                           = local.cluster_name
  docker_cfg_secret_name                 = var.create_docker_pull_secret && length(google_secret_manager_secret.docker_cfg) > 0 ? google_secret_manager_secret.docker_cfg[0].secret_id : null
  docker_email                           = var.docker_email
  docker_password                        = var.docker_password
  docker_registry_server                 = var.docker_registry_server
  docker_pull_secret_name                = var.docker_pull_secret_name
  create_docker_pull_secret              = var.create_docker_pull_secret
  docker_username                        = var.docker_username
  domain                                 = var.domain
  env_secret_name                        = google_secret_manager_secret.env.secret_id
  external_secrets_service_account_email = google_service_account.eso.email
  feature_flags_content                  = local.feature_flags_content
  flipt_options                          = local.flipt_options
  gcp_creds                              = local.gcp_creds
  helm_values                            = local.helm_values_public
  secrets_revision = sha256(jsonencode({
    env             = google_secret_manager_secret_version.env.name
    docker_cfg      = length(google_secret_manager_secret_version.docker_cfg) > 0 ? google_secret_manager_secret_version.docker_cfg[0].name : null
    managed_sync    = var.managed_sync_enabled ? google_secret_manager_secret_version.managed_sync[0].name : null
    openobserve     = google_secret_manager_secret_version.openobserve[0].name
    openobserve_gcs = local.gcp_creds != null ? google_secret_manager_secret_version.openobserve_gcs[0].name : null
  }))
  ingress_scheme              = var.ingress_scheme
  k8s_version                 = var.k8s_version
  logs_bucket                 = local.logs_bucket
  managed_sync_enabled        = var.managed_sync_enabled
  managed_sync_secret_name    = var.managed_sync_enabled ? google_secret_manager_secret.managed_sync[0].secret_id : null
  managed_sync_version        = var.managed_sync_version
  microservices               = local.microservices
  monitor_version             = local.monitor_version
  monitors                    = local.monitors
  monitors_enabled            = var.monitors_enabled
  openobserve_email           = local.openobserve_email
  openobserve_gcs_secret_name = local.gcp_creds != null ? google_secret_manager_secret.openobserve_gcs[0].secret_id : null
  openobserve_password        = local.openobserve_password
  openobserve_secret_name     = google_secret_manager_secret.openobserve[0].secret_id
  public_microservices        = local.public_microservices
  public_monitors             = local.public_monitors
  public_services             = local.public_services
  redis_ca_cert_secret_name   = local.infra_secret_names.redis_ca_cert
  region                      = var.region
  storage_service_account     = try(local.storage_output.service_account, null)
  infra_vars                  = local.infra_vars
  waf_security_policy_name    = local.waf_active ? module.waf[0].security_policy_name : ""
  waf_logs_sample_rate        = var.waf_logs_sample_rate
  workspace                   = local.workspace
}

module "hoop" {
  source = "./hoop"

  workspace                     = local.workspace
  organization                  = var.organization
  hoop_agent_name               = var.hoop_agent_name
  hoop_enabled                  = var.hoop_enabled
  hoop_key                      = var.hoop_key
  hoop_agent_id                 = var.hoop_agent_id
  hoop_slack_bot_token          = var.hoop_slack_bot_token
  hoop_slack_app_token          = var.hoop_slack_app_token
  hoop_slack_channel_ids        = var.hoop_slack_channel_ids
  all_access_groups             = var.hoop_all_access_groups
  restricted_access_groups      = var.hoop_restricted_access_groups
  reviewers_access_groups       = var.hoop_reviewers_access_groups
  hoop_postgres_guardrail_rules = var.hoop_postgres_guardrail_rules
  hoop_redis_guardrail_rules    = var.hoop_redis_guardrail_rules
  customer_facing               = var.customer_facing
  hoop_grafana_connection       = var.hoop_grafana_connection
  namespace_paragon             = module.helm.namespace_paragon
  custom_connections            = var.hoop_custom_connections
  k8s_connections               = var.hoop_k8s_connections
  gcp_project_id                = local.gcp_project_id
  infra_vars = {
    postgres = try(local.infra_vars.postgres, null)
    redis    = try(local.infra_vars.redis, null)
  }
}

module "monitors" {
  source = "./monitors"
  count  = var.monitors_enabled ? 1 : 0

  grafana_admin_email    = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_USER"], null)
  grafana_admin_password = try(local.helm_vars.global.env["MONITOR_GRAFANA_SECURITY_ADMIN_PASSWORD"], null)
  pgadmin_admin_email    = try(local.helm_vars.global.env["MONITOR_PGADMIN_EMAIL"], null)
  pgadmin_admin_password = try(local.helm_vars.global.env["MONITOR_PGADMIN_PASSWORD"], null)
  workspace              = local.workspace
}

module "uptime" {
  source = "./uptime"

  uptime_api_token = var.uptime_api_token
  uptime_company   = coalesce(var.uptime_company, var.organization)
  microservices    = local.uptime_services
}

module "dns" {
  source = "./dns"

  enabled              = local.dns_enabled
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  domain               = var.domain
  ingress_loadbalancer = module.helm.load_balancer
}
