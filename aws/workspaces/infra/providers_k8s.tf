# Kubernetes API access for GitOps bootstrap (ArgoCD, ESO, platform manifests).
# Uses the same credentials as the AWS provider (Spacelift / assumed role) via EKS
# access entries on the cluster — not the bastion host.
data "aws_eks_cluster_auth" "gitops" {
  name = module.cluster.eks_cluster.name
}

provider "kubernetes" {
  host                   = module.cluster.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.gitops.token
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.gitops.token
  }
}
