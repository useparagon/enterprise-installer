# module.eks outputs (not data.aws_eks_cluster) so greenfield can create the cluster and
# the Karpenter Helm controller in one infra apply. EC2NodeClass / NodePool CRs are applied
# from the paragon workspace after infra apply (data.aws_eks_cluster).

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.this.token
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.this.token
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  }
}
