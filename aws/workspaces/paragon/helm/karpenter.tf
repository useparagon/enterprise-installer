module "karpenter" {
  count  = var.karpenter_enabled && var.karpenter_aws != null ? 1 : 0
  source = "../karpenter"

  workspace                       = var.workspace
  k8s_version                     = var.k8s_version
  ebs_volume_size_gib             = var.karpenter_node_volume_size_gib
  aws                             = var.karpenter_aws
  eks_ondemand_node_instance_type = var.eks_ondemand_node_instance_type
  eks_spot_node_instance_type     = var.eks_spot_node_instance_type
  eks_spot_instance_percent       = var.eks_spot_instance_percent
  eks_max_node_count              = var.eks_max_node_count
  karpenter_defaults              = var.karpenter_defaults
  karpenter_node_pool_overrides   = var.karpenter_node_pool_overrides
  karpenter_node_pools            = var.karpenter_node_pools
}
