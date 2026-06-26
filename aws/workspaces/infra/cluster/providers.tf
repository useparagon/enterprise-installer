# module.eks outputs (not data.aws_eks_cluster) so greenfield can create the cluster and
# Kubernetes resources in one apply. hashicorp/kubernetes and helm defer unknown endpoint
# until the cluster exists; alekc/kubectl does not, so Karpenter CRs use kubernetes_manifest.

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
