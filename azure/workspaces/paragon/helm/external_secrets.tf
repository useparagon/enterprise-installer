resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = kubernetes_namespace.external_secrets.id
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.14.4"
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }
}

resource "helm_release" "reloader" {
  name             = "reloader"
  namespace        = kubernetes_namespace.external_secrets.id
  repository       = "https://stakater.github.io/stakater-charts"
  chart            = "reloader"
  version          = "2.2.11"
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
}

resource "kubernetes_secret" "external_secrets_azure_auth" {
  metadata {
    name      = "external-secrets-azure-auth"
    namespace = kubernetes_namespace.paragon.id
  }

  data = {
    ClientID     = var.external_secrets_client_id
    ClientSecret = var.external_secrets_client_secret
  }
}

locals {
  secret_store_yaml = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "azure-key-vault"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      provider = {
        azurekv = {
          authType = "ServicePrincipal"
          tenantId = var.external_secrets_tenant_id
          vaultUrl = "https://${var.key_vault_name}.vault.azure.net"
          authSecretRef = {
            clientId = {
              name = kubernetes_secret.external_secrets_azure_auth.metadata[0].name
              key  = "ClientID"
            }
            clientSecret = {
              name = kubernetes_secret.external_secrets_azure_auth.metadata[0].name
              key  = "ClientSecret"
            }
          }
        }
      }
    }
  })

  external_secret_paragon_yaml = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "paragon-secrets"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "azure-key-vault"
        kind = "SecretStore"
      }
      target = {
        name           = "paragon-secrets"
        creationPolicy = "Owner"
      }
      dataFrom = [{
        extract = {
          key = var.env_secret_name
        }
      }]
    }
  })

  external_secret_docker_yaml = var.create_docker_pull_secret && var.docker_cfg_secret_name != null ? yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = var.docker_pull_secret_name
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "azure-key-vault"
        kind = "SecretStore"
      }
      target = {
        name           = var.docker_pull_secret_name
        creationPolicy = "Owner"
        template = {
          type = "kubernetes.io/dockerconfigjson"
          data = {
            ".dockerconfigjson" = "{{ .dockerconfigjson }}"
          }
        }
      }
      data = [{
        secretKey = "dockerconfigjson"
        remoteRef = {
          key      = var.docker_cfg_secret_name
          property = "dockerconfigjson"
        }
      }]
    }
  }) : null

  external_secret_managed_sync_yaml = var.managed_sync_secret_name != null ? yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "paragon-managed-sync-secrets"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "azure-key-vault"
        kind = "SecretStore"
      }
      target = {
        name           = "paragon-managed-sync-secrets"
        creationPolicy = "Owner"
      }
      dataFrom = [{
        extract = {
          key = var.managed_sync_secret_name
        }
      }]
    }
  }) : null

  external_secret_openobserve_yaml = var.openobserve_secret_name != null ? yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "openobserve-credentials"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "azure-key-vault"
        kind = "SecretStore"
      }
      target = {
        name           = "openobserve-credentials"
        creationPolicy = "Owner"
      }
      dataFrom = [{
        extract = {
          key = var.openobserve_secret_name
        }
      }]
    }
  }) : null
}

resource "kubectl_manifest" "secret_store" {
  yaml_body  = local.secret_store_yaml
  depends_on = [helm_release.external_secrets, kubernetes_secret.external_secrets_azure_auth]
}

resource "kubectl_manifest" "external_secret_paragon" {
  yaml_body  = local.external_secret_paragon_yaml
  depends_on = [kubectl_manifest.secret_store]
}

resource "kubectl_manifest" "external_secret_docker" {
  count = local.external_secret_docker_yaml != null ? 1 : 0

  yaml_body  = local.external_secret_docker_yaml
  depends_on = [kubectl_manifest.secret_store]
}

resource "kubectl_manifest" "external_secret_managed_sync" {
  count      = local.external_secret_managed_sync_yaml != null ? 1 : 0
  yaml_body  = local.external_secret_managed_sync_yaml
  depends_on = [kubectl_manifest.secret_store]
}

resource "kubectl_manifest" "external_secret_openobserve" {
  count      = local.external_secret_openobserve_yaml != null ? 1 : 0
  yaml_body  = local.external_secret_openobserve_yaml
  depends_on = [kubectl_manifest.secret_store]
}
