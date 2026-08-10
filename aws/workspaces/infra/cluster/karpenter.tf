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
  chart_version           = var.karpenter_chart_version
  interruption_queue_name = module.sqs[0].queue_name

  depends_on = [
    module.eks,
    module.eks_managed_node_group,
    module.sqs,
    module.iam,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
    aws_eks_addon.aws_ebs_csi_driver,
    aws_eks_addon.eks_pod_identity_agent,
    time_sleep.wait_for_eks_api,
  ]
}
