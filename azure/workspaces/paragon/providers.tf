provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  # AGC lives in Microsoft.ServiceNetworking, which is outside the default set.
  resource_providers_to_register = var.agc_enabled ? ["Microsoft.ServiceNetworking"] : []

  features {}
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_config[0].host
  username               = data.azurerm_kubernetes_cluster.cluster.kube_config[0].username
  password               = data.azurerm_kubernetes_cluster.cluster.kube_config[0].password
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.cluster.kube_config[0].host
    username               = data.azurerm_kubernetes_cluster.cluster.kube_config[0].username
    password               = data.azurerm_kubernetes_cluster.cluster.kube_config[0].password
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_config[0].host
  username               = data.azurerm_kubernetes_cluster.cluster.kube_config[0].username
  password               = data.azurerm_kubernetes_cluster.cluster.kube_config[0].password
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate)
  load_config_file       = false
}

provider "hoop" {
  api_url = var.hoop_api_url
  api_key = coalesce(var.hoop_api_key, "dummy-token")
}

