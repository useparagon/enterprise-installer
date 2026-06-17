# Subnets and the EKS cluster primary security group must carry karpenter.sh/discovery so
# EC2NodeClass objects (created from the paragon workspace) can select them.
resource "aws_ec2_tag" "karpenter_discovery_subnet" {
  for_each = var.enable_karpenter ? toset(module.network.private_subnet[*].id) : []

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = module.cluster.eks_cluster.name
}

resource "aws_ec2_tag" "karpenter_discovery_cluster_sg" {
  count = var.enable_karpenter ? 1 : 0

  resource_id = module.cluster.eks_cluster.sg_id
  key         = "karpenter.sh/discovery"
  value       = module.cluster.eks_cluster.name
}
