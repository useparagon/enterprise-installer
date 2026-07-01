module "karpenter" {
  count  = var.karpenter_enabled && var.karpenter_aws != null ? 1 : 0
  source = "../karpenter"

  workspace              = var.workspace
  k8s_version            = var.k8s_version
  ebs_os_volume_size_gib = var.karpenter_node_os_volume_size_gib
  ebs_volume_size_gib    = var.karpenter_node_volume_size_gib
  aws                    = var.karpenter_aws
  karpenter_node_pools   = var.karpenter_node_pools
  karpenter_defaults     = var.karpenter_defaults
}
