locals {
  api_sync_host = replace(replace(try(var.microservices["api-sync"].public_url, ""), "https://", ""), "http://", "")

  # Single values document for chart-specific overrides (keep one entry in helm_release.values
  # so plan/apply does not churn on yaml fragment ordering).
  managed_sync_chart_values = yamlencode({
    # openfga-migrate is a post-install hook while the openfga ServiceAccount is normally
    # a regular resource. On first install, the cluster can create the Job before the SA is
    # visible, producing: serviceaccount "openfga" not found.
    openfga = {
      enabled = true
      serviceAccount = {
        annotations = {
          "helm.sh/hook"        = "pre-install,pre-upgrade"
          "helm.sh/hook-weight" = "-10"
        }
      }
    }
    # queue-exporter.common defaults to shared: false and renders a standalone Ingress
    # (chart-example.local, internal NLB group). Disable it on AWS; sync traffic uses the
    # parent chart Ingress on the shared paragon ALB group (ingress.loadBalancerName).
    queue-exporter = {
      common = {
        ingress = {
          enabled = false
        }
      }
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
    ingress = {
      className = "alb"
      annotations = merge(
        {
          "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "false"
        },
        var.waf_web_acl_arn != "" ? {
          "alb.ingress.kubernetes.io/wafv2-acl-arn" = var.waf_web_acl_arn
        } : {}
      )
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
  namespace        = local.paragon_namespace
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  timeout          = 900 # 15 minutes
  # Parent chart renders ScaledObject; KEDA CRDs come from the subchart. OpenAPI
  # validation runs before subchart CRDs exist (and manual CRD fixes break Helm ownership).
  disable_openapi_validation = true

  values = [
    local.global_values_minus_env,
    local.managed_sync_chart_values,
    local.secret_hash,
  ]

  set {
    name  = "secretName"
    value = "paragon-managed-sync-secrets"
  }

  set {
    name  = "ingress.certificate"
    value = var.certificate
  }

  set {
    name  = "ingress.host"
    value = local.api_sync_host
  }

  set {
    name  = "ingress.loadBalancerName"
    value = var.workspace
  }

  set {
    name  = "ingress.logsBucket"
    value = var.logs_bucket
  }

  set {
    name  = "ingress.listenPorts[0].HTTP"
    value = "80"
  }

  set {
    name  = "ingress.listenPorts[1].HTTPS"
    value = "443"
  }

  # configures whether the load balancer is 'internet-facing' (public) or 'internal' (private)
  set {
    name  = "ingress.scheme"
    value = var.ingress_scheme
  }

  depends_on = [
    module.karpenter,
    helm_release.ingress,
    data.kubernetes_secret.docker_cfg,
    data.kubernetes_secret.paragon_secrets,
    data.kubernetes_secret.managed_sync_secrets,
    kubernetes_secret.docker_login,
    kubernetes_storage_class_v1.gp3_encrypted,
  ]
}
