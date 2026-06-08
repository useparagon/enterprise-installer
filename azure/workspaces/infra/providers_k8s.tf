provider "kubernetes" {
  host = try(module.cluster.kubernetes.host, "")

  client_certificate     = try(base64decode(module.cluster.kubernetes.client_certificate), "")
  client_key             = try(base64decode(module.cluster.kubernetes.client_key), "")
  cluster_ca_certificate = try(base64decode(module.cluster.kubernetes.cluster_ca_certificate), "")
}

provider "helm" {
  kubernetes {
    host = try(module.cluster.kubernetes.host, "")

    client_certificate     = try(base64decode(module.cluster.kubernetes.client_certificate), "")
    client_key             = try(base64decode(module.cluster.kubernetes.client_key), "")
    cluster_ca_certificate = try(base64decode(module.cluster.kubernetes.cluster_ca_certificate), "")
  }
}

provider "kubectl" {
  host = try(module.cluster.kubernetes.host, "")

  client_certificate     = try(base64decode(module.cluster.kubernetes.client_certificate), "")
  client_key             = try(base64decode(module.cluster.kubernetes.client_key), "")
  cluster_ca_certificate = try(base64decode(module.cluster.kubernetes.cluster_ca_certificate), "")
  load_config_file       = false
}
