module "network" {
  source = "./network"

  location  = var.location
  tags      = local.default_tags
  vpc_cidr  = var.vpc_cidr
  workspace = local.workspace
}

module "bastion" {
  source = "./bastion"

  azure_subscription_id = var.azure_subscription_id
  cluster_id            = module.cluster.kubernetes.id

  bastion_vm_size                = var.bastion_vm_size
  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_tunnel_account_id   = var.cloudflare_tunnel_account_id
  cloudflare_tunnel_email_domain = var.cloudflare_tunnel_email_domain
  cloudflare_tunnel_enabled      = var.cloudflare_tunnel_enabled
  cloudflare_tunnel_subdomain    = var.cloudflare_tunnel_subdomain
  cloudflare_tunnel_zone_id      = var.cloudflare_tunnel_zone_id

  cluster_name   = module.cluster.kubernetes.name
  k8s_version    = var.k8s_version
  private_subnet = module.network.private_subnet
  resource_group = module.network.resource_group
  ssh_whitelist  = local.ssh_whitelist
  tags           = local.default_tags
  workspace      = local.workspace
}

module "postgres" {
  source = "./postgres"

  managed_sync_enabled        = var.managed_sync_enabled
  postgres_multiple_instances = var.postgres_multiple_instances
  postgres_base_sku_name      = var.postgres_base_sku_name
  postgres_redundant          = var.postgres_redundant
  postgres_sku_name           = var.postgres_sku_name
  postgres_version            = var.postgres_version
  resource_group              = module.network.resource_group
  tags                        = local.default_tags
  virtual_network             = module.network.virtual_network
  private_subnet              = module.network.postgres_subnet
  workspace                   = local.workspace
}

module "redis" {
  source = "./redis"

  managed_sync_enabled     = var.managed_sync_enabled
  private_subnet           = module.network.private_subnet
  public_subnet            = module.network.public_subnet
  redis_base_capacity      = var.redis_base_capacity
  redis_base_sku_name      = var.redis_base_sku_name
  redis_capacity           = var.redis_capacity
  redis_multiple_instances = var.redis_multiple_instances
  redis_sku_name           = var.redis_sku_name
  redis_ssl_only           = var.redis_ssl_only
  redis_subnet             = module.network.redis_subnet
  resource_group           = module.network.resource_group
  tags                     = local.default_tags
  virtual_network          = module.network.virtual_network
  workspace                = local.workspace
}

module "storage" {
  source = "./storage"

  managed_sync_enabled       = var.managed_sync_enabled
  storage_account_tier       = var.storage_account_tier
  auditlogs_lock_enabled     = var.auditlogs_lock_enabled
  auditlogs_retention_days   = var.auditlogs_retention_days
  resource_group             = module.network.resource_group
  tags                       = local.default_tags
  virtual_network_subnet_ids = [module.network.public_subnet.id, module.network.private_subnet.id]
  workspace                  = local.workspace
}

module "cluster" {
  source = "./cluster"

  k8s_default_node_pool_vm_size   = var.k8s_default_node_pool_vm_size
  k8s_max_node_count              = var.k8s_max_node_count
  k8s_min_node_count              = var.k8s_min_node_count
  k8s_ondemand_node_instance_type = var.k8s_ondemand_node_instance_type
  k8s_sku_tier                    = var.k8s_sku_tier
  k8s_spot_instance_percent       = var.k8s_spot_instance_percent
  k8s_spot_node_instance_type     = var.k8s_spot_node_instance_type
  k8s_version                     = var.k8s_version
  private_subnet                  = module.network.private_subnet
  resource_group                  = module.network.resource_group
  tags                            = local.default_tags
  workspace                       = local.workspace
}

module "kafka" {
  count  = var.managed_sync_enabled ? 1 : 0
  source = "./kafka"

  eventhub_auto_inflate_enabled     = var.eventhub_auto_inflate_enabled
  eventhub_capacity                 = var.eventhub_capacity
  eventhub_maximum_throughput_units = var.eventhub_maximum_throughput_units
  eventhub_namespace_sku            = var.eventhub_namespace_sku
  private_subnet                    = module.network.private_subnet
  resource_group                    = module.network.resource_group
  tags                              = local.default_tags
  virtual_network                   = module.network.virtual_network
  workspace                         = local.workspace
}

module "argocd" {
  count  = var.argocd_enabled ? 1 : 0
  source = "./argocd"

  # Identity / cluster
  workspace                 = local.workspace
  azure_location            = var.location
  azure_subscription_id     = var.azure_subscription_id
  azure_tenant_id           = coalesce(var.azure_tenant_id, data.azurerm_client_config.current.tenant_id)
  azure_resource_group_name = module.network.resource_group.name
  azure_node_resource_group = module.cluster.kubernetes.node_resource_group
  cluster_name              = module.cluster.kubernetes.name
  oidc_issuer_url           = module.cluster.oidc_issuer_url
  key_vault_name            = local.key_vault_name
  key_vault_id              = azurerm_key_vault.paragon.id
  key_vault_uri             = azurerm_key_vault.paragon.vault_uri

  # Secret content — computed by argocd_env.tf and root variables
  env_config             = local.argocd_env_secret
  docker_username        = var.argocd_docker_username
  docker_password        = var.argocd_docker_password
  docker_registry_server = var.argocd_docker_registry_server
  docker_email           = var.argocd_docker_email
  managed_sync_config    = var.paragon_managed_sync_config

  # DNS / Cloudflare
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_tunnel_zone_id

  # ArgoCD tooling
  argocd_version            = var.argocd_version
  argocd_helm_chart_version = var.argocd_helm_chart_version
  eso_chart_version         = var.eso_chart_version
  argocd_addon_overrides    = var.argocd_addon_overrides

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
  paragon_chart_version        = var.paragon_chart_version
  paragon_monitor_version      = var.paragon_monitor_version
  paragon_managed_sync_version = var.paragon_managed_sync_version
  paragon_monitors_enabled     = var.paragon_monitors_enabled
  managed_sync_enabled         = var.managed_sync_enabled
  ingress_scheme               = var.argocd_ingress_scheme

  # Ensure the Terraform SP Key Vault access policy exists before the module
  # attempts to write secrets, and that the cluster is ready for Helm installs.
  depends_on = [
    azurerm_key_vault_access_policy.terraform,
    module.cluster,
  ]
}
