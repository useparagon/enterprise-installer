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

  values = [
    local.global_values_minus_env,
    local.secret_hash
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
    value = replace(replace(var.microservices["api-sync"].public_url, "https://", ""), "http://", "")
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
    terraform_data.managed_ingress_controller_ready,
    terraform_data.external_ingress_controller_ready,
    data.kubernetes_secret.docker_cfg,
    data.kubernetes_secret.paragon_secrets,
    data.kubernetes_secret.managed_sync_secrets,
    kubernetes_storage_class_v1.gp3_encrypted
  ]
}
