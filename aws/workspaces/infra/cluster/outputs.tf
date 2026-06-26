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

output "enable_karpenter" {
  description = "Whether Karpenter autoscaling is enabled. Consumed by paragon workspace for EC2NodeClass and NodePool manifests."
  value       = var.enable_karpenter
}

output "enable_legacy_mng_pools" {
  description = "Whether legacy on-demand and spot managed node groups are active. Consumed by paragon workspace for conditional NTH."
  value       = var.enable_karpenter ? var.enable_legacy_mng_pools : true
}

output "karpenter" {
  description = "Karpenter NodePool and EC2NodeClass inputs for the paragon workspace. Null when enable_karpenter is false."
  value = var.enable_karpenter ? {
    kubernetes_version      = var.k8s_version
    node_iam_role_name      = module.iam[0].node_iam_role_name
    node_security_group_ids = local.eks_worker_security_group_ids
    discovery_tag_value     = var.workspace
    availability_zones      = data.aws_availability_zones.available.names
    ec2_node_classes        = local.karpenter_ec2_node_classes
    ebs_kms_key_arn         = module.ebs_kms_key.key_arn
    ami_selector_alias      = local.karpenter_defaults_effective.ami_selector_alias
    ec2_kubelet_max_pods    = try(local.karpenter_defaults_effective.ec2_kubelet_max_pods, null)
    metadata_options        = local.metadata_options
    node_pool_definitions   = local.karpenter_node_pool_definitions
    node_pool_effective     = local.karpenter_pool_effective_with_names
  } : null
}
