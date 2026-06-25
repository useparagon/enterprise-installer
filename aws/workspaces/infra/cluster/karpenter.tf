module "sqs" {
  count  = var.enable_karpenter ? 1 : 0
  source = "./sqs"

  cluster_name      = module.eks.cluster_name
  kms_master_key_id = module.ebs_kms_key.key_id
  tags = {
    ClusterName = var.workspace
  }

  depends_on = [
    module.eks,
    module.ebs_kms_key,
  ]
}

module "iam" {
  count  = var.enable_karpenter ? 1 : 0
  source = "./iam"

  cluster_name           = module.eks.cluster_name
  aws_region             = var.aws_region
  controller_role_name   = local.karpenter_controller_role_name
  node_role_name         = local.karpenter_node_role_name
  interruption_queue_arn = module.sqs[0].queue_arn
  kms_key_arn            = module.ebs_kms_key.key_arn
  node_iam_role_additional_policies = local.karpenter_node_iam_additional_policies
  tags = {
    ClusterName = var.workspace
  }

  depends_on = [
    module.eks,
    module.sqs,
  ]
}

module "karpenter" {
  count  = var.enable_karpenter ? 1 : 0
  source = "./karpenter"

  cluster_name            = module.eks.cluster_name
  cluster_endpoint        = module.eks.cluster_endpoint
  kubernetes_version      = var.k8s_version
  chart_version           = var.karpenter_chart_version
  interruption_queue_name = module.sqs[0].queue_name
  node_iam_role_name      = module.iam[0].node_iam_role_name
  node_security_group_ids = local.eks_worker_security_group_ids
  discovery_tag_value     = var.workspace
  availability_zones      = data.aws_availability_zones.available.names
  ec2_node_classes        = local.karpenter_ec2_node_classes
  ebs_kms_key_arn         = module.ebs_kms_key.key_arn
  ebs_volume_size_gib     = local.node_volume_size
  ami_selector_alias      = local.karpenter_defaults_effective.ami_selector_alias
  ec2_kubelet_max_pods    = try(local.karpenter_defaults_effective.ec2_kubelet_max_pods, null)
  node_pool_definitions   = local.karpenter_node_pool_definitions
  node_pool_effective     = local.karpenter_pool_effective_with_names

  depends_on = [
    module.eks,
    module.eks_managed_node_group,
    module.sqs,
    module.iam,
    aws_eks_addon.eks_pod_identity_agent,
  ]
}
