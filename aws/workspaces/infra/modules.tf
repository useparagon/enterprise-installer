module "network" {
  source = "./network"

  workspace        = local.workspace
  aws_region       = var.aws_region
  az_count         = var.az_count
  vpc_cidr         = var.vpc_cidr
  vpc_cidr_newbits = var.vpc_cidr_newbits
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

module "storage" {
  source = "./storage"

  workspace                = local.workspace
  force_destroy            = var.disable_deletion_protection
  app_bucket_expiration    = var.app_bucket_expiration
  auditlogs_retention_days = var.auditlogs_retention_days
  auditlogs_lock_enabled   = var.auditlogs_lock_enabled
  managed_sync_enabled     = var.managed_sync_enabled

  migrated = var.migrated_workspace != null
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
}

module "cluster" {
  source = "./cluster"

  workspace = local.workspace

  bastion_role_arn          = module.bastion.bastion_role_arn
  bastion_security_group_id = module.bastion.security_group.host[0]

  argocd_enabled                  = var.argocd_enabled
  create_autoscaling_linked_role  = var.create_autoscaling_linked_role
  eks_admin_arns                  = var.eks_admin_arns
  eks_max_node_count              = var.eks_max_node_count
  eks_min_node_count              = var.eks_min_node_count
  eks_ondemand_node_instance_type = local.eks_ondemand_node_instance_type
  eks_spot_instance_percent       = var.eks_spot_instance_percent
  eks_spot_node_instance_type     = local.eks_spot_node_instance_type
  k8s_version                     = var.k8s_version

  vpc_id             = module.network.vpc.id
  private_subnet_ids = module.network.private_subnet[*].id
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps modules — only created when argocd_enabled = true
# ---------------------------------------------------------------------------

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.23"

  cluster_name      = module.cluster.eks_cluster.name
  cluster_endpoint  = module.cluster.eks_cluster.cluster_endpoint
  cluster_version   = var.k8s_version
  oidc_provider_arn = module.cluster.eks_cluster.oidc_provider_arn
  observability_tag = null

  enable_argocd                         = var.argocd_enabled
  enable_external_secrets               = var.argocd_enabled
  external_secrets                      = local.gitops_external_secrets
  external_secrets_secrets_manager_arns = local.gitops_eso_secret_arns

  enable_aws_load_balancer_controller = var.argocd_enabled
  aws_load_balancer_controller        = local.gitops_aws_load_balancer_controller

  enable_external_dns = local.gitops_ingress_enabled
  external_dns        = local.gitops_external_dns
  external_dns_route53_zone_arns = local.gitops_ingress_enabled ? [
    aws_route53_zone.paragon[0].arn,
  ] : []
  argocd = merge(
    {
      name             = "argo-cd"
      namespace        = "argocd"
      create_namespace = true
      chart_version    = var.argocd_helm_chart_version
      values = [yamlencode({
        global = {
          image = {
            tag = var.argocd_version
          }
        }
        configs = {
          params = {
            "server.insecure" = true
          }
        }
        crds = {
          install = true
          keep    = true
        }
      })]
      wait          = true
      wait_for_jobs = true
      timeout       = 600
    },
    var.argocd_addon_overrides
  )

  tags = local.default_tags

  depends_on = [module.cluster]
}

module "secrets" {
  source = "./secrets"
  count  = var.argocd_enabled && local.argocd_secrets_ready ? 1 : 0

  workspace    = local.workspace
  organization = var.organization
  env_config   = local.argocd_env_secret

  docker_config = jsonencode({
    dockerconfigjson = jsonencode({
      auths = {
        (var.argocd_docker_registry_server) = {
          username = var.argocd_docker_username
          password = var.argocd_docker_password
          email    = var.argocd_docker_email
          auth     = base64encode("${var.argocd_docker_username}:${var.argocd_docker_password}")
        }
      }
    })
  })

  managed_sync_config     = var.paragon_managed_sync_config
  openobserve_credentials = local.argocd_openobserve_credentials

  recovery_window_in_days = var.secrets_recovery_window_in_days
}

module "argocd" {
  source = "./argocd"
  count  = var.argocd_enabled ? 1 : 0

  cluster_name      = module.cluster.eks_cluster.name
  oidc_provider_arn = module.cluster.eks_cluster.oidc_provider_arn
  oidc_issuer_url   = module.cluster.eks_cluster.cluster_oidc_issuer_url
  workspace         = local.workspace
  aws_region        = var.aws_region

  argocd_release_name = "argo-cd"
  eso_role_arn        = try(module.eks_blueprints_addons.external_secrets.iam_role_arn, null)
  eso_crds_ready      = time_sleep.gitops_eso_crds[0].id

  secrets_manager_secret_arns = local.argocd_secrets_ready ? module.secrets[0].secret_arns : []

  destination_namespace     = "paragon"
  cluster_secret_store_name = "aws-secrets-manager"
  env_secret_name           = local.argocd_secrets_ready ? module.secrets[0].env_secret_name : null
  docker_cfg_secret_name    = local.argocd_secrets_ready ? module.secrets[0].docker_cfg_secret_name : null
  managed_sync_secret_name  = local.argocd_secrets_ready ? module.secrets[0].managed_sync_secret_name : null
  openobserve_secret_name   = local.argocd_secrets_ready ? module.secrets[0].openobserve_secret_name : null

  bootstrap_repo_url      = var.argocd_bootstrap_repo_url
  bootstrap_repo_path     = var.argocd_bootstrap_repo_path
  bootstrap_repo_revision = var.argocd_bootstrap_repo_revision
  bootstrap_repo_token    = var.argocd_bootstrap_repo_token
  auto_sync               = var.argocd_auto_sync
  self_heal               = var.argocd_self_heal
  paragon_certificate_arn = local.paragon_certificate_arn
  paragon_domain          = local.paragon_domain_trimmed

  app_chart_repository         = var.argocd_app_chart_repository
  paragon_chart_version        = var.paragon_chart_version
  paragon_monitor_version      = var.paragon_monitor_version
  paragon_managed_sync_version = var.paragon_managed_sync_version
  paragon_monitors_enabled     = var.paragon_monitors_enabled
  managed_sync_enabled         = var.managed_sync_enabled
  ingress_scheme               = var.argocd_ingress_scheme

  depends_on = [
    module.cluster,
    module.eks_blueprints_addons,
    time_sleep.gitops_eso_crds,
  ]
}
