# Core EKS add-ons use stable resource addresses regardless of enable_karpenter so migration
# does not destroy/recreate vpc-cni (and strand new Karpenter nodes without CNI).

moved {
  from = aws_eks_addon.addons["vpc-cni"]
  to   = aws_eks_addon.vpc_cni
}

moved {
  from = aws_eks_addon.addons["kube-proxy"]
  to   = aws_eks_addon.kube_proxy
}

moved {
  from = aws_eks_addon.addons["coredns"]
  to   = aws_eks_addon.coredns
}

moved {
  from = aws_eks_addon.addons["aws-ebs-csi-driver"]
  to   = aws_eks_addon.aws_ebs_csi_driver
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = local.eks_addon_versions["vpc-cni"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [module.eks_managed_node_group]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = local.eks_addon_versions["kube-proxy"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [aws_eks_addon.vpc_cni]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  addon_version               = local.eks_addon_versions["coredns"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [aws_eks_addon.kube_proxy]
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = local.eks_addon_versions["aws-ebs-csi-driver"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update
  service_account_role_arn    = module.aws_ebs_csi_driver_iam_role.iam_role_arn

  depends_on = [
    aws_eks_addon.coredns,
    module.aws_ebs_csi_driver_iam_role,
  ]
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name                = module.eks.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = local.eks_addon_versions["eks-pod-identity-agent"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
  ]
}
