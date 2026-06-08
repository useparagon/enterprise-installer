# Kubernetes API access for GitOps bootstrap (ArgoCD, ESO, platform manifests).
# Uses GKE access token from the google provider (Application Default Credentials / SA).

provider "kubernetes" {
  host                   = try(module.cluster.kubernetes.host, "")
  token                  = try(module.cluster.kubernetes.token, "")
  cluster_ca_certificate = try(module.cluster.kubernetes.cluster_ca_certificate, "")
}

provider "helm" {
  kubernetes {
    host                   = try(module.cluster.kubernetes.host, "")
    token                  = try(module.cluster.kubernetes.token, "")
    cluster_ca_certificate = try(module.cluster.kubernetes.cluster_ca_certificate, "")
  }
}

# kubectl provider applies custom resources via server-side apply at apply-time and does
# NOT validate the GroupVersionKind at plan-time.
provider "kubectl" {
  host                   = try(module.cluster.kubernetes.host, "")
  token                  = try(module.cluster.kubernetes.token, "")
  cluster_ca_certificate = try(module.cluster.kubernetes.cluster_ca_certificate, "")
  load_config_file       = false
}

provider "time" {}
