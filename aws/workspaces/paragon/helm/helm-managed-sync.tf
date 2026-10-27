locals {
  api_sync_public_url      = try(var.microservices["api-sync"].public_url, "")
  api_sync_host            = replace(local.api_sync_public_url, "/^https?:\\/\\/([^\\/?#]+).*$/", "$1")
  managed_sync_path_prefix = try(var.public_microservices["api-sync"].path_prefix, "")
  # The chart ingress stays on sync.<domain>. A path on the public URL is a
  # separate hostless ALB rule; the chart does not strip that prefix.
  api_sync_ingress_host = local.managed_sync_path_prefix != "" ? "sync.${var.domain}" : local.api_sync_host

  managed_sync_path_routes = [
    { path = "/api/sync-projects", service = "api-project", port = try(var.microservices["api-project"].port, 1804) },
    { path = "/api/catalog", service = "api-project", port = try(var.microservices["api-project"].port, 1804) },
    { path = "/api/syncs", service = "api-sync", port = try(var.microservices["api-sync"].port, 1800) },
    { path = "/api/permissions", service = "api-sync", port = try(var.microservices["api-sync"].port, 1800) },
    { path = "/api/webhooks", service = "api-webhook", port = 1809 },
    { path = "/worker/sync", service = "worker-sync", port = try(var.microservices["worker-sync"].port, 1802) },
    { path = "/worker/history/sync", service = "worker-history-sync", port = 1807 },
    { path = "/", service = "api-sync", port = try(var.microservices["api-sync"].port, 1800) },
  ]

  # Single values document for chart-specific overrides (keep one entry in helm_release.values
  # so plan/apply does not churn on yaml fragment ordering).
  managed_sync_chart_values = yamlencode(merge({
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
    }, (var.agent_os_enabled || local.managed_sync_path_prefix != "") ? {
    # Leave existing Managed Sync values untouched until Agent OS or path routing is enabled.
    global = {
      env = merge(
        var.agent_os_enabled ? {
          MANAGED_SYNC_KAFKA_SKIP_CONTEXT_TOPIC_CREATION = "false"
          MANAGED_SYNC_STATUS_EVENTS_ENABLED             = "true"
        } : {},
        local.managed_sync_path_prefix != "" ? {
          HTTP_PATH_PREFIX = local.managed_sync_path_prefix
        } : {}
      )
    }
  } : {}))
}

resource "helm_release" "managed_sync" {
  count = var.managed_sync_enabled ? 1 : 0

  name             = "paragon-managed-sync"
  description      = "Managed Sync"
  repository       = var.paragon_helm_repository
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
    value = local.api_sync_ingress_host
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

# Hostless path rules on the shared ALB. The chart ingress stays on sync.<domain>.
resource "kubectl_manifest" "managed_sync_path_ingress" {
  count = var.managed_sync_enabled && var.path_based_routing_enabled && local.managed_sync_path_prefix != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "managed-sync-path"
      namespace = local.paragon_namespace
      annotations = merge(
        {
          "kubernetes.io/ingress.class"                                   = "alb"
          "alb.ingress.kubernetes.io/group.name"                          = var.workspace
          "alb.ingress.kubernetes.io/group.order"                         = "-100"
          "alb.ingress.kubernetes.io/load-balancer-name"                  = var.workspace
          "alb.ingress.kubernetes.io/scheme"                              = var.ingress_scheme
          "alb.ingress.kubernetes.io/target-type"                         = "ip"
          "alb.ingress.kubernetes.io/listen-ports"                        = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
          "alb.ingress.kubernetes.io/certificate-arn"                     = var.certificate
          "alb.ingress.kubernetes.io/ssl-redirect"                        = "443"
          "alb.ingress.kubernetes.io/healthcheck-path"                    = "/healthz"
          "alb.ingress.kubernetes.io/success-codes"                       = "200"
          "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "false"
        },
        var.waf_web_acl_arn != "" ? {
          "alb.ingress.kubernetes.io/wafv2-acl-arn" = var.waf_web_acl_arn
        } : {}
      )
    }
    spec = {
      ingressClassName = "alb"
      rules = [{
        http = {
          paths = [
            for route in local.managed_sync_path_routes : {
              path     = route.path == "/" ? local.managed_sync_path_prefix : "${local.managed_sync_path_prefix}${route.path}"
              pathType = "Prefix"
              backend = {
                service = {
                  name = route.service
                  port = {
                    number = route.port
                  }
                }
              }
            }
          ]
        }
      }]
    }
  })

  depends_on = [helm_release.managed_sync]
}
