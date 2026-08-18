locals {
  # One HTTPS listener per host, reusing the per-host certificates cert-manager already
  # issues for nginx. This keeps AGC off the DNS-01 wildcard, so enabling it never waits
  # on a DNS delegation and never touches live TLS.
  https_listeners = {
    for name, svc in var.public_services :
    name => {
      listener = "https-${name}"
      host     = svc.host
      secret   = "${name}-secret"
    }
  }

  gateway_yaml = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = local.gateway_name
      namespace = var.namespace
      annotations = {
        # ALB-managed frontend: the controller provisions and owns the frontend for this
        # Gateway. Read the assigned FQDN from the Gateway status, not a Terraform frontend.
        "alb.networking.azure.io/alb-id" = try(azurerm_application_load_balancer.this[0].id, "")
      }
    }
    spec = {
      gatewayClassName = local.gateway_class
      listeners = concat(
        [{
          name     = local.http_listener
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = { from = "Same" }
          }
        }],
        [
          for name, cfg in local.https_listeners : {
            name     = cfg.listener
            port     = 443
            protocol = "HTTPS"
            hostname = cfg.host
            tls = {
              mode = "Terminate"
              certificateRefs = [{
                kind = "Secret"
                name = cfg.secret
              }]
            }
            allowedRoutes = {
              namespaces = { from = "Same" }
            }
          }
        ],
      )
    }
  })

  # HTTP -> HTTPS redirect.
  redirect_route_yaml = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${local.gateway_name}-https-redirect"
      namespace = var.namespace
    }
    spec = {
      parentRefs = [{
        name        = local.gateway_name
        sectionName = local.http_listener
      }]
      rules = [{
        filters = [{
          type = "RequestRedirect"
          requestRedirect = {
            scheme     = "https"
            statusCode = 301
          }
        }]
      }]
    }
  })

  # Transition: forward HTTPS to ingress-nginx (existing Ingress objects).
  nginx_route_yaml = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${local.gateway_name}-nginx"
      namespace = var.namespace
    }
    spec = {
      parentRefs = [
        for name, cfg in local.https_listeners : {
          name        = local.gateway_name
          sectionName = cfg.listener
        }
      ]
      rules = [{
        backendRefs = [{
          name = var.nginx_service_name
          port = var.nginx_service_port
        }]
      }]
    }
  })

  # Direct: one HTTPRoute per public host to the workload Service.
  direct_route_yaml = {
    for name, svc in var.public_services :
    name => yamlencode({
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "HTTPRoute"
      metadata = {
        name      = "${local.gateway_name}-${name}"
        namespace = var.namespace
      }
      spec = {
        parentRefs = [{
          name        = local.gateway_name
          sectionName = local.https_listeners[name].listener
        }]
        hostnames = [svc.host]
        rules = [{
          backendRefs = [{
            name = name
            port = svc.port
          }]
        }]
      }
    })
  }
}

resource "kubectl_manifest" "gateway" {
  count = var.enabled ? 1 : 0

  yaml_body = local.gateway_yaml

  depends_on = [helm_release.alb_controller]
}

# The controller programs the ALB-managed frontend asynchronously. Waiting here makes the
# first greenfield apply return a usable agc_fqdn instead of racing the Gateway status.
resource "time_sleep" "gateway_programming" {
  count = var.enabled ? 1 : 0

  create_duration = "90s"
  triggers = {
    gateway_manifest = sha256(local.gateway_yaml)
  }

  depends_on = [
    kubectl_manifest.gateway,
    kubectl_manifest.nginx_route,
    kubectl_manifest.direct_route,
  ]
}

# The ALB controller assigns the frontend FQDN to the Gateway status once programmed.
data "kubernetes_resource" "gateway" {
  count = var.enabled ? 1 : 0

  api_version = "gateway.networking.k8s.io/v1"
  kind        = "Gateway"

  metadata {
    name      = local.gateway_name
    namespace = var.namespace
  }

  depends_on = [
    time_sleep.gateway_programming,
  ]
}

resource "kubectl_manifest" "https_redirect_route" {
  count = var.enabled ? 1 : 0

  yaml_body  = local.redirect_route_yaml
  depends_on = [kubectl_manifest.gateway]
}

resource "kubectl_manifest" "nginx_route" {
  count = local.nginx_route_enabled ? 1 : 0

  yaml_body  = local.nginx_route_yaml
  depends_on = [kubectl_manifest.gateway]
}

resource "kubectl_manifest" "direct_route" {
  for_each = local.direct_routes_enabled ? local.direct_route_yaml : {}

  yaml_body  = each.value
  depends_on = [kubectl_manifest.gateway]
}
