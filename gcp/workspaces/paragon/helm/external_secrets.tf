resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = kubernetes_namespace_v1.external_secrets.id
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

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = var.external_secrets_service_account_email
  }
}

resource "helm_release" "reloader" {
  name             = "reloader"
  namespace        = kubernetes_namespace_v1.external_secrets.id
  repository       = "https://stakater.github.io/stakater-charts"
  chart            = "reloader"
  version          = "2.2.11"
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
}

locals {
  secret_store_yaml = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "gcp-secret-manager"
    }
    spec = {
      provider = {
        gcpsm = {
          auth = {
            workloadIdentity = {
              clusterLocation = var.region
              clusterName     = var.cluster_name
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = kubernetes_namespace_v1.external_secrets.id
              }
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
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
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
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
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
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
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

  external_secret_openobserve_yaml = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "openobserve-credentials"
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
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
  })

  external_secret_openobserve_gcs_yaml = var.openobserve_gcs_secret_name != null ? yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "openobserve-creds"
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "openobserve-creds"
        creationPolicy = "Owner"
      }
      data = [{
        secretKey = "creds.json"
        remoteRef = {
          key      = var.openobserve_gcs_secret_name
          property = "creds.json"
        }
      }]
    }
  }) : null

  external_secret_redis_ca_yaml = var.redis_ca_cert_secret_name != null ? yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "redis-ca-cert"
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "redis-ca-cert"
        creationPolicy = "Owner"
      }
      data = [{
        secretKey = "server-ca.pem"
        remoteRef = {
          key      = var.redis_ca_cert_secret_name
          property = "server-ca.pem"
        }
      }]
    }
  }) : null
}

resource "kubectl_manifest" "secret_store" {
  yaml_body  = local.secret_store_yaml
  depends_on = [helm_release.external_secrets, kubernetes_namespace_v1.paragon]
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
  yaml_body  = local.external_secret_openobserve_yaml
  depends_on = [kubectl_manifest.secret_store]
}

resource "kubectl_manifest" "external_secret_openobserve_gcs" {
  count      = local.external_secret_openobserve_gcs_yaml != null ? 1 : 0
  yaml_body  = local.external_secret_openobserve_gcs_yaml
  depends_on = [kubectl_manifest.secret_store]
}

resource "kubectl_manifest" "external_secret_redis_ca" {
  count      = local.external_secret_redis_ca_yaml != null ? 1 : 0
  yaml_body  = local.external_secret_redis_ca_yaml
  depends_on = [kubectl_manifest.secret_store]
}
