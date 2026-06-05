resource "kubernetes_namespace" "external_secrets" {
  count = var.install_external_secrets ? 1 : 0

  metadata {
    name = "external-secrets"
  }
}

resource "helm_release" "external_secrets" {
  count = var.install_external_secrets ? 1 : 0

  name             = "external-secrets"
  namespace        = kubernetes_namespace.external_secrets[0].id
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
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.eso_role_arn
  }
}

resource "helm_release" "reloader" {
  name             = "reloader"
  namespace        = "kube-system"
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
    kind       = "SecretStore"
    metadata = {
      name      = "aws-secrets-manager"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
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
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      refreshInterval = "5m"
      secretStoreRef = {
        name = "aws-secrets-manager"
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

  external_secret_docker_yaml = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "docker-cfg"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-secrets-manager"
        kind = "SecretStore"
      }
      target = {
        name           = "docker-cfg"
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
  })

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
        name = "aws-secrets-manager"
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
        name = "aws-secrets-manager"
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
  count = var.install_external_secrets ? 1 : 0

  yaml_body  = local.secret_store_yaml
  depends_on = [helm_release.external_secrets[0], kubernetes_namespace.paragon, terraform_data.runtime_secrets_ready]
}

resource "kubectl_manifest" "external_secret_paragon" {
  count = var.install_external_secrets ? 1 : 0

  yaml_body  = local.external_secret_paragon_yaml
  depends_on = [kubectl_manifest.secret_store[0]]
}

resource "kubectl_manifest" "external_secret_docker" {
  count = var.install_external_secrets ? 1 : 0

  yaml_body  = local.external_secret_docker_yaml
  depends_on = [kubectl_manifest.secret_store[0]]
}

resource "kubectl_manifest" "external_secret_managed_sync" {
  count = var.install_external_secrets && local.external_secret_managed_sync_yaml != null ? 1 : 0

  yaml_body  = local.external_secret_managed_sync_yaml
  depends_on = [kubectl_manifest.secret_store[0]]
}

resource "kubectl_manifest" "external_secret_openobserve" {
  count = var.install_external_secrets && local.external_secret_openobserve_yaml != null ? 1 : 0

  yaml_body  = local.external_secret_openobserve_yaml
  depends_on = [kubectl_manifest.secret_store[0]]
}
