module "karpenter" {
  count  = var.karpenter_config != null ? 1 : 0
  source = "../karpenter"

  kubernetes_version      = var.karpenter_config.kubernetes_version
  node_iam_role_name      = var.karpenter_config.node_iam_role_name
  node_security_group_ids = var.karpenter_config.node_security_group_ids
  discovery_tag_value     = var.karpenter_config.discovery_tag_value
  availability_zones      = var.karpenter_config.availability_zones
  ec2_node_classes        = var.karpenter_config.ec2_node_classes
  ebs_kms_key_arn         = var.karpenter_config.ebs_kms_key_arn
  ebs_volume_size_gib     = var.karpenter_node_volume_size_gib
  ami_selector_alias      = var.karpenter_config.ami_selector_alias
  ec2_kubelet_max_pods    = try(var.karpenter_config.ec2_kubelet_max_pods, null)
  metadata_options        = var.karpenter_config.metadata_options
  node_pool_definitions   = var.karpenter_config.node_pool_definitions
  node_pool_effective     = var.karpenter_config.node_pool_effective
}
