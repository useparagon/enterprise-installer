# Greenfield EKS: API auth and access entries can lag cluster creation by tens of seconds.
# Helm (Karpenter controller) fails with "server has asked for the client to provide credentials"
# if it runs too early; a single apply must succeed without manual retry.
resource "time_sleep" "wait_for_eks_api" {
  count = var.enable_karpenter ? 1 : 0

  create_duration = "60s"

  triggers = {
    cluster_name     = module.eks.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
  }

  depends_on = [
    module.eks,
    module.eks_managed_node_group,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
    aws_eks_addon.aws_ebs_csi_driver,
    aws_eks_addon.eks_pod_identity_agent,
  ]
}
