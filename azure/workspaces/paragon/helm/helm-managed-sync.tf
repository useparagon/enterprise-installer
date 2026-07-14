locals {
  # api-sync is only in var.microservices when managed_sync_enabled is true, but locals
  # are always evaluated — use try() so plan succeeds when managed sync is disabled.
  api_sync_host = replace(replace(try(var.microservices["api-sync"].public_url, ""), "https://", ""), "http://", "")

  # openfga-migrate is a post-install hook while the openfga ServiceAccount is normally
  # a regular resource. On first install, AKS can create the Job before the SA is
  # visible, producing: serviceaccount "openfga" not found.
  managed_sync_openfga_values = yamlencode({
    openfga = {
      enabled = true
      serviceAccount = {
        annotations = {
          "helm.sh/hook"        = "pre-install,pre-upgrade"
          "helm.sh/hook-weight" = "-10"
        }
      }
    }
  })

  # queue-exporter.common defaults to shared: false with class: nlb (→ ingressClassName
  # alb). On Azure the common ingress template hardcodes kubernetes.io/ingress.class:
  # nginx, which conflicts with ingressClassName. Disable the standalone ingress since
  # queue-exporter is internal-only (public_url is null).
  #
  # postgres-config-* jobs must finish before openfga-migrate (post-install hook) creates
  # the openfga schema. With prehookEnabled: false they race and migrate fails when the
  # database does not exist yet, leaving openfga pods stuck in wait-for-migration.
  managed_sync_azure_values = yamlencode({
    ingress = {
      class     = "nginx"
      className = "nginx"
    }
    "api-sync" = {
      ingress = {
        class     = "nginx"
        className = "nginx"
        host      = local.api_sync_host
        annotations = {
          "kubernetes.io/ingress.class"    = "nginx"
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        scheme = var.ingress_scheme
      }
      tls_secret = "api-sync-secret"
    }
    bootstrap = {
      postgres = {
        configOpenFGA = {
          prehookEnabled = true
        }
        configProject = {
          prehookEnabled = true
        }
        configSyncInstance = {
          prehookEnabled = true
        }
      }
    }
    queue-exporter = {
      common = {
        ingress = {
          enabled = false
        }
      }
    }
  })
}

resource "helm_release" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name             = "paragon-managed-sync"
  description      = "Managed Sync"
  repository       = "https://paragon-helm-production.s3.amazonaws.com"
  chart            = "managed-sync"
  version          = var.managed_sync_version
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 600 # 10 minutes

  values = [
    local.global_values_minus_env,
    local.public_microservice_values,
    local.managed_sync_azure_values,
    local.managed_sync_openfga_values,
    local.managed_sync_values,
    local.secret_hash
  ]

  set {
    name  = "ingress.host"
    value = local.api_sync_host
  }

  set {
    name  = "ingress.loadBalancerName"
    value = var.workspace
  }

  set {
    name  = "secretName"
    value = "paragon-managed-sync-secrets"
  }

  depends_on = [
    helm_release.ingress,
    kubectl_manifest.external_secret_docker,
    kubectl_manifest.external_secret_paragon,
    kubectl_manifest.external_secret_managed_sync
  ]
}
