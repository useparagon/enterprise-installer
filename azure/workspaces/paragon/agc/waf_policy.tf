# Helm owns the Kubernetes WAF policy; Azure SecurityPolicy alone does not
# enable inspection. Bind it to the Gateway for both NGINX and direct modes.
resource "helm_release" "waf_policy" {
  count = var.enabled && var.waf_enabled ? 1 : 0

  name      = "agc-waf-policy"
  namespace = var.namespace
  chart     = "${path.module}/charts/waf-policy"

  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "gatewayName"
    value = local.gateway_name
  }

  set {
    name  = "wafPolicyId"
    value = var.waf_policy_id
  }

  depends_on = [
    kubectl_manifest.gateway,
    azurerm_application_load_balancer_security_policy.waf,
  ]
}
