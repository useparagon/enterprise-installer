output "eks_cluster" {
  value = {
    name                               = var.workspace
    arn                                = module.eks.cluster_arn
    id                                 = module.eks.cluster_id
    sg_id                              = module.eks.cluster_primary_security_group_id
    oidc_provider_arn                  = module.eks.oidc_provider_arn
    cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
    cluster_endpoint                   = module.eks.cluster_endpoint
    cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  }
}

output "enable_legacy_mng_pools" {
  description = "Whether legacy on-demand and spot managed node groups are active. Consumed by paragon workspace for conditional NTH."
  value       = var.enable_karpenter ? var.enable_legacy_mng_pools : true
}
