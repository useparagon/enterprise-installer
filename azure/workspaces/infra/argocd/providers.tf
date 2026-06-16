# Kubernetes providers live in this module (not the infra root) so they are only
# configured when the module is instantiated. Callers must not use count/for_each
# on module "argocd"; gate resources with var.argocd_enabled instead.
provider "kubernetes" {
  host = var.cluster_host

  client_certificate     = base64decode(var.cluster_client_certificate)
  client_key             = base64decode(var.cluster_client_key)
  cluster_ca_certificate = base64decode(var.cluster_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = var.cluster_host

    client_certificate     = base64decode(var.cluster_client_certificate)
    client_key             = base64decode(var.cluster_client_key)
    cluster_ca_certificate = base64decode(var.cluster_cluster_ca_certificate)
  }
}

provider "kubectl" {
  host = var.cluster_host

  client_certificate     = base64decode(var.cluster_client_certificate)
  client_key             = base64decode(var.cluster_client_key)
  cluster_ca_certificate = base64decode(var.cluster_cluster_ca_certificate)
  load_config_file       = false
}
