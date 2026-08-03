# Logs bucket policy must exist before Network Firewall logging configuration.
module "storage" {
  source = "./storage"

  workspace                 = local.workspace
  aws_region                = var.aws_region
  network_firewall_enabled  = var.network_firewall.enabled
  force_destroy             = var.disable_deletion_protection
  app_bucket_expiration     = var.app_bucket_expiration
  auditlogs_retention_days  = var.auditlogs_retention_days
  auditlogs_lock_enabled    = var.auditlogs_lock_enabled
  managed_sync_enabled      = var.managed_sync_enabled
  s3_kms_encryption_enabled = var.s3_kms_encryption_enabled
  s3_kms_key_arn            = var.s3_kms_key_arn
  admin_arns                = local.admin_arns

  migrated             = var.migrated_workspace != null
  cdn_bucket_acl_reset = var.cdn_bucket_acl_reset
}

module "network" {
  source = "./network"

  workspace                = local.workspace
  aws_region               = var.aws_region
  az_count                 = var.az_count
  vpc_cidr                 = var.vpc_cidr
  vpc_cidr_newbits         = var.vpc_cidr_newbits
  network_firewall_enabled = var.network_firewall.enabled
  logs_bucket_name         = module.storage.logs_bucket_name
  network_firewall         = var.network_firewall
}

module "cloudtrail" {
  count  = var.disable_cloudtrail ? 0 : 1
  source = "./cloudtrail"

  workspace                   = local.workspace
  aws_region                  = var.aws_region
  master_guardduty_account_id = var.master_guardduty_account_id
  mfa_enabled                 = var.mfa_enabled
  force_destroy               = var.disable_deletion_protection
}

module "postgres" {
  source = "./postgres"

  workspace                   = local.workspace
  aws_region                  = var.aws_region
  rds_instance_class          = var.rds_instance_class
  rds_gp3_iops                = var.rds_gp3_iops
  rds_gp3_storage_throughput  = var.rds_gp3_storage_throughput
  rds_allocated_storage       = var.rds_allocated_storage
  rds_max_allocated_storage   = var.rds_max_allocated_storage
  rds_multi_az                = var.rds_multi_az
  rds_multiple_instances      = var.rds_multiple_instances
  rds_postgres_version        = var.rds_postgres_version
  rds_restore_from_snapshot   = var.rds_restore_from_snapshot
  rds_final_snapshot_enabled  = var.rds_final_snapshot_enabled
  disable_deletion_protection = var.disable_deletion_protection
  managed_sync_enabled        = var.managed_sync_enabled
  migrated_passwords          = var.migrated_passwords

  vpc                = module.network.vpc
  public_subnet      = module.network.public_subnet
  private_subnet     = module.network.private_subnet
  availability_zones = module.network.availability_zones
}

module "redis" {
  source = "./redis"

  workspace                      = local.workspace
  aws_region                     = var.aws_region
  elasticache_node_type          = var.elasticache_node_type
  elasticache_multi_az           = var.elasticache_multi_az
  elasticache_multiple_instances = var.elasticache_multiple_instances
  managed_sync_enabled           = var.managed_sync_enabled

  vpc            = module.network.vpc
  public_subnet  = module.network.public_subnet
  private_subnet = module.network.private_subnet
}

module "kafka" {
  source = "./kafka"
  count  = var.managed_sync_enabled ? 1 : 0

  workspace                  = local.workspace
  force_destroy              = var.disable_deletion_protection
  msk_autoscaling_enabled    = var.msk_autoscaling_enabled
  msk_kafka_version          = var.msk_kafka_version
  msk_instance_type          = var.msk_instance_type
  msk_kafka_num_broker_nodes = var.msk_kafka_num_broker_nodes

  private_subnet = module.network.private_subnet
  vpc_id         = module.network.vpc.id
}

module "bastion" {
  count  = var.bastion_enabled ? 1 : 0
  source = "./bastion"

  workspace     = local.workspace
  aws_region    = var.aws_region
  ssh_whitelist = local.ssh_whitelist

  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_tunnel_enabled      = var.cloudflare_tunnel_enabled
  cloudflare_tunnel_subdomain    = var.cloudflare_tunnel_subdomain
  cloudflare_tunnel_zone_id      = var.cloudflare_tunnel_zone_id
  cloudflare_tunnel_account_id   = var.cloudflare_tunnel_account_id
  cloudflare_tunnel_email_domain = var.cloudflare_tunnel_email_domain

  cluster_name   = local.workspace
  k8s_version    = var.k8s_version
  private_subnet = module.network.private_subnet
  public_subnet  = module.network.public_subnet
  vpc_id         = module.network.vpc.id

  # Workloads that bootstrap over the internet must wait for egress routing (NFW or NAT).
  egress_ready = module.network.egress_ready
}

module "cluster" {
  source = "./cluster"

  workspace  = local.workspace
  aws_region = var.aws_region

  egress_ready = module.network.egress_ready

  bastion_enabled           = var.bastion_enabled
  bastion_role_arn          = var.bastion_enabled ? module.bastion[0].bastion_role_arn : null
  bastion_security_group_id = var.bastion_enabled ? module.bastion[0].security_group.host[0] : null

  argocd_enabled                  = var.argocd_enabled
  create_autoscaling_linked_role  = var.create_autoscaling_linked_role
  eks_admin_arns                  = local.admin_arns
  eks_max_node_count              = var.eks_max_node_count
  eks_min_node_count              = var.eks_min_node_count
  eks_ondemand_node_instance_type = local.eks_ondemand_node_instance_type
  eks_spot_instance_percent       = var.eks_spot_instance_percent
  eks_spot_node_instance_type     = local.eks_spot_node_instance_type
  k8s_version                     = var.k8s_version

  enable_karpenter                  = var.enable_karpenter
  enable_legacy_mng_pools           = var.enable_legacy_mng_pools
  karpenter_chart_version           = var.karpenter_chart_version
  karpenter_iam_names               = var.karpenter_iam_names
  karpenter_node_os_volume_size_gib = var.karpenter_node_os_volume_size_gib
  karpenter_node_volume_size_gib    = var.karpenter_node_volume_size_gib
  karpenter_node_pools              = var.karpenter_node_pools
  karpenter_defaults                = var.karpenter_defaults
  eks_system_managed_node_group     = var.eks_system_managed_node_group

  vpc_id             = module.network.vpc.id
  private_subnet_ids = module.network.private_subnet[*].id
}

# ---------------------------------------------------------------------------
# Application secrets (flat env for ESO) — always created by infra (PARA-21726).
# Paragon workspace reads these secrets and overlays chart-specific values only.
# ---------------------------------------------------------------------------

module "secrets" {
  source = "./secrets"

  workspace    = local.workspace
  organization = var.organization
  env_config   = local.argocd_env_secret

  docker_config = (
    local.secrets_docker_username != null &&
    local.secrets_docker_password != null
    ) ? jsonencode({
      dockerconfigjson = jsonencode({
        auths = {
          (local.secrets_docker_registry_server) = {
            username = local.secrets_docker_username
            password = local.secrets_docker_password
            email    = local.secrets_docker_email
            auth     = base64encode("${local.secrets_docker_username}:${local.secrets_docker_password}")
          }
        }
      })
  }) : null

  managed_sync_config     = var.managed_sync_enabled ? coalesce(var.paragon_managed_sync_config, {}) : null
  create_openobserve      = true
  openobserve_email       = var.openobserve_email
  recovery_window_in_days = var.secrets_recovery_window_in_days
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps — only created when argocd_enabled = true
# ---------------------------------------------------------------------------

module "argocd" {
  count  = var.argocd_enabled ? 1 : 0
  source = "./argocd"

  argocd_enabled = true

  # Identity / cluster
  cluster_name               = module.cluster.eks_cluster.name
  cluster_autoscaler_enabled = module.cluster.cluster_autoscaler_enabled
  oidc_provider_arn          = module.cluster.eks_cluster.oidc_provider_arn
  oidc_issuer_url            = module.cluster.eks_cluster.cluster_oidc_issuer_url
  workspace                  = local.workspace
  aws_region                 = var.aws_region

  # Application secrets — from root secrets module
  secrets_manager_secret_arns = module.secrets.secret_arns
  env_secret_name             = module.secrets.env_secret_name
  docker_cfg_secret_name      = module.secrets.docker_cfg_secret_name
  managed_sync_secret_name    = module.secrets.managed_sync_secret_name
  openobserve_secret_name     = module.secrets.openobserve_secret_name

  # DNS / Cloudflare / TLS
  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_zone_id             = var.cloudflare_tunnel_zone_id
  paragon_certificate_arn        = var.paragon_certificate_arn
  gitops_alb_ingressclass_exists = var.gitops_alb_ingressclass_exists

  # ArgoCD tooling
  argocd_version            = var.argocd_version
  argocd_helm_chart_version = var.argocd_helm_chart_version
  eso_chart_version         = var.eso_chart_version
  argocd_addon_overrides    = var.argocd_addon_overrides
  eso_addon_overrides       = var.eso_addon_overrides

  destination_namespace     = "paragon"
  cluster_secret_store_name = "aws-secrets-manager"

  # Bootstrap repo
  bootstrap_repo_url      = var.argocd_bootstrap_repo_url
  bootstrap_repo_path     = var.argocd_bootstrap_repo_path
  bootstrap_repo_revision = var.argocd_bootstrap_repo_revision
  bootstrap_repo_token    = var.argocd_bootstrap_repo_token
  auto_sync               = var.argocd_auto_sync
  self_heal               = var.argocd_self_heal

  # Paragon application
  paragon_domain               = local.paragon_domain_trimmed
  app_chart_repository         = var.argocd_app_chart_repository
  paragon_managed_sync_version = var.paragon_managed_sync_version
  paragon_monitors_enabled     = var.paragon_monitors_enabled
  managed_sync_enabled         = var.managed_sync_enabled
  ingress_scheme               = var.argocd_ingress_scheme

  depends_on = [module.cluster, module.secrets]
}

# ---------------------------------------------------------------------------
# WAF (public ALB) — annotation wired via gitops values (wafv2_acl_arn)
# ---------------------------------------------------------------------------

locals {
  waf_active = var.waf_enabled && var.argocd_ingress_scheme == "internet-facing"

  # ServiceAccount names must match chart SA names (paragon-onprem / managed-sync).
  paragon_service_accounts = toset(concat(
    [
      "account",
      "api-triggerkit",
      "cache-replay",
      "cerberus",
      "connect",
      "dashboard",
      "flipt",
      "hades",
      "health-checker",
      "hermes",
      "passport",
      "pheme",
      "release",
      "zeus",
      "worker-actionkit",
      "worker-actions",
      "worker-auditlogs",
      "worker-credentials",
      "worker-crons",
      "worker-deployments",
      "worker-eventlogs",
      "worker-proxy",
      "worker-triggerkit",
      "worker-triggers",
      "worker-workflows",
    ],
    var.managed_sync_enabled ? ["managed-sync-service-account"] : [],
  ))
}

module "waf" {
  source = "./waf"
  count  = local.waf_active ? 1 : 0

  aws_region                       = var.aws_region
  workspace                        = local.workspace
  waf_logs_retention_days          = var.waf_logs_retention_days
  waf_ip_whitelist                 = var.waf_ip_whitelist
  waf_ip_blacklist                 = var.waf_ip_blacklist
  waf_rate_limit_global            = var.waf_rate_limit_global
  waf_rate_limit_global_window_sec = var.waf_rate_limit_global_window_sec
  waf_rate_limit_paths             = var.waf_rate_limit_paths
  waf_rate_limit_path_window_sec   = var.waf_rate_limit_path_window_sec
  waf_managed_rule_groups          = var.waf_managed_rule_groups
}

module "pod_identity" {
  source = "./pod-identity"
  count  = try(module.storage.s3.role_arn, null) != null ? 1 : 0

  cluster_name     = module.cluster.eks_cluster.name
  namespace        = "paragon"
  s3_role_arn      = module.storage.s3.role_arn
  service_accounts = local.paragon_service_accounts

  depends_on = [module.cluster]
}

module "monitors" {
  source = "./monitors"
  count  = var.paragon_monitors_enabled ? 1 : 0

  workspace    = local.workspace
  cluster_name = module.cluster.eks_cluster.name
  namespace    = "paragon"

  depends_on = [module.cluster]
}

# Hoop remains Terraform-managed while the Paragon application moves to ArgoCD.
# The fixed namespace is owned by the application bootstrap/chart path.
module "hoop" {
  count  = var.hoop_enabled ? 1 : 0
  source = "./hoop"

  workspace                     = local.workspace
  organization                  = var.organization
  namespace                     = "paragon"
  hoop_agent_name               = var.hoop_agent_name
  hoop_agent_id                 = var.hoop_agent_id
  hoop_key                      = var.hoop_key
  hoop_slack_bot_token          = var.hoop_slack_bot_token
  hoop_slack_app_token          = var.hoop_slack_app_token
  hoop_slack_channel_ids        = var.hoop_slack_channel_ids
  all_access_groups             = var.hoop_all_access_groups
  restricted_access_groups      = var.hoop_restricted_access_groups
  reviewers_access_groups       = var.hoop_reviewers_access_groups
  hoop_postgres_guardrail_rules = var.hoop_postgres_guardrail_rules
  hoop_redis_guardrail_rules    = var.hoop_redis_guardrail_rules
  hoop_grafana_connection       = var.hoop_grafana_connection
  customer_facing               = var.customer_facing
  custom_connections            = var.hoop_custom_connections
  k8s_connections               = var.hoop_k8s_connections

  eks_oidc_provider_arn = module.cluster.eks_cluster.oidc_provider_arn
  eks_oidc_issuer_url   = module.cluster.eks_cluster.cluster_oidc_issuer_url
  infra_vars = {
    postgres = { value = module.postgres.rds }
    redis    = { value = module.redis.elasticache }
  }

  depends_on = [module.cluster, module.argocd]
}

module "uptime" {
  source = "./uptime"

  uptime_api_token = var.uptime_api_token
  uptime_company   = coalesce(var.uptime_company, var.organization)
  uptime_policy    = var.uptime_policy
  uptime_regions   = var.uptime_regions
  microservices    = local.uptime_services
}
