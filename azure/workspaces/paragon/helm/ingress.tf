# Key Vault is owned by the infra workspace (runtime handoff + app secrets).
# Must match the sanitized name from infra/runtime_secrets.tf.
data "azurerm_key_vault" "paragon" {
  name                = replace(substr(var.workspace, 0, 24), "/-+$/", "")
  resource_group_name = var.resource_group.name
}

locals {
  # Same enablement as root agc_public_routes / helm subchart_values: every
  # microservice forced on, then helm_values.subchart overrides. Avoids issuing
  # LE certs for hosts Helm does not actually publish (e.g. cache-replay).
  subchart_enabled = merge(
    { for name in keys(var.microservices) : name => { enabled = true } },
    try(nonsensitive(var.helm_values.subchart), {}),
  )

  # Hostnames that need Certificate CRs when nginx Ingress is gone (AGC direct).
  agc_direct_certificate_hosts = {
    for name, cfg in merge(var.public_microservices, var.public_monitors) :
    name => replace(replace(cfg.public_url, "https://", ""), "http://", "")
    if lookup(cfg, "public_url", null) != null && try(local.subchart_enabled[name].enabled, true)
  }
}

resource "azurerm_key_vault_access_policy" "aks_access_to_kv" {
  key_vault_id = data.azurerm_key_vault.paragon.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_kubernetes_cluster.cluster.kubelet_identity.0.object_id

  certificate_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.paragon.id
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"

  force_update     = false
  create_namespace = false

  set {
    name  = "installCRDs"
    value = true
  }

  # Required for ACME HTTP-01 via Gateway API when AGC direct-routing removes nginx.
  set {
    name  = "extraArgs[0]"
    value = "--enable-gateway-api"
  }
}

# Public static IP for nginx when nginx keeps a public LB.
resource "azurerm_public_ip" "ingress" {
  count = var.nginx_public ? 1 : 0

  name                = "AKS-Ingress-Controller"
  allocation_method   = "Static"
  domain_name_label   = var.workspace
  location            = var.resource_group.location
  resource_group_name = data.azurerm_kubernetes_cluster.cluster.node_resource_group
  sku                 = "Standard"
}

resource "helm_release" "ingress" {
  count = var.nginx_enabled ? 1 : 0

  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.paragon.id
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.15.1"

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  dynamic "set" {
    for_each = var.nginx_public ? [1] : []
    content {
      name  = "controller.service.loadBalancerIP"
      value = azurerm_public_ip.ingress[0].ip_address
    }
  }

  # Internal LB when nginx is not public.
  dynamic "set" {
    for_each = var.nginx_public ? [] : [1]
    content {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
      value = "true"
    }
  }

  set {
    name  = "controller.service.annotations.service\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_kubernetes_cluster.cluster.node_resource_group
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  set {
    name  = "controller.config.proxy-buffers-number"
    value = "8"
  }

  set {
    name  = "controller.config.proxy-buffer-size"
    value = "16k"
  }

  # Trust X-Forwarded-For from AGC during transition.
  dynamic "set" {
    for_each = var.agc_active ? [1] : []
    content {
      name  = "controller.config.use-forwarded-headers"
      value = "true"
    }
  }

  dynamic "set" {
    for_each = var.agc_active && var.agc_subnet_cidr != null ? [1] : []
    content {
      name  = "controller.config.proxy-real-ip-cidr"
      value = var.agc_subnet_cidr
    }
  }

  depends_on = [
    helm_release.cert_manager,
    azurerm_key_vault_access_policy.aks_access_to_kv,
    azurerm_public_ip.ingress
  ]
}

resource "time_sleep" "wait" {
  create_duration = "60s"

  depends_on = [helm_release.ingress]
}

resource "kubectl_manifest" "certificate_issuer_http01" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name      = "letsencrypt-prod"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "enterprise@useparagon.com"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        # Transition (nginx present): HTTP-01 via ingress-nginx.
        # Direct (nginx removed): HTTP-01 via temporary HTTPRoutes on the AGC Gateway.
        # Encode each branch before the ternary so object shapes need not match.
        solvers = jsondecode(
          var.agc_direct ? jsonencode([{
            http01 = {
              gatewayHTTPRoute = {
                parentRefs = [{
                  group     = "gateway.networking.k8s.io"
                  kind      = "Gateway"
                  name      = var.agc_gateway_name
                  namespace = kubernetes_namespace.paragon.id
                }]
              }
            }
          }]) : jsonencode([{
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }])
        )
      }
    }
  })

  depends_on = [
    helm_release.cert_manager,
    time_sleep.wait,
  ]
}

# In AGC direct mode Ingress (and ingress-shim Certificates) are gone. Own the
# Certificate CRs here so renewals keep updating the per-host secrets AGC terminates.
resource "kubectl_manifest" "agc_direct_certificate" {
  for_each = var.agc_direct ? local.agc_direct_certificate_hosts : {}

  # Do not block apply on ACME; cert-manager renews asynchronously and existing
  # TLS secrets stay valid while challenges complete.
  wait_for_rollout = false

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "${each.key}-secret"
      namespace = kubernetes_namespace.paragon.id
    }
    spec = {
      secretName = "${each.key}-secret"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = [each.value]
    }
  })

  depends_on = [
    kubectl_manifest.certificate_issuer_http01,
    helm_release.cert_manager,
  ]
}

