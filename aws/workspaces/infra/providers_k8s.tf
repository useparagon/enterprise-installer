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

# kubectl provider applies custom resources via server-side apply at apply-time and does
# NOT validate the GroupVersionKind at plan-time. This is required for CRs (ClusterSecretStore,
# ExternalSecret, ArgoCD Application) whose CRDs are installed earlier in the same apply.
provider "kubectl" {
  host                   = module.cluster.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.gitops.token
  load_config_file       = false
}
