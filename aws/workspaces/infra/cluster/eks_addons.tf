# Legacy path: parallel add-ons with PRESERVE on update (existing clusters).
resource "aws_eks_addon" "addons" {
  for_each = var.enable_karpenter ? {} : local.cluster_addons_legacy

  addon_name                  = each.key
  addon_version               = try(each.value.version, null)
  cluster_name                = module.eks.cluster_name
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = each.key == "aws-ebs-csi-driver" ? module.aws_ebs_csi_driver_iam_role.iam_role_arn : null

  depends_on = [
    module.eks_managed_node_group,
    module.aws_ebs_csi_driver_iam_role
  ]
}

# Karpenter path: chained add-ons (one UPDATE at a time). Post-Karpenter add-ons depend on module.karpenter.
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = local.eks_addon_versions["vpc-cni"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [module.eks_managed_node_group]
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name                = module.eks.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = local.eks_addon_versions["eks-pod-identity-agent"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [aws_eks_addon.vpc_cni]
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = local.eks_addon_versions["kube-proxy"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [
    module.karpenter[0],
    aws_eks_addon.eks_pod_identity_agent,
  ]
}

resource "aws_eks_addon" "coredns" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  addon_version               = local.eks_addon_versions["coredns"]
  resolve_conflicts_on_create = local.eks_addon_resolve_conflicts.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.eks_addon_resolve_conflicts.resolve_conflicts_on_update

  depends_on = [aws_eks_addon.kube_proxy]
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  count = var.enable_karpenter ? 1 : 0

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
