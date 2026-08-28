# The hoopagent chart has no podLabels. Workload Identity's mutating webhook only
# injects Azure env/token volume when this label is on the pod template, so the
# Helm-owned Deployment has to be patched via server-side apply.
resource "kubectl_manifest" "hoopagent_workload_identity_label" {
  count = local.hoop_workload_identity_enabled ? 1 : 0

  server_side_apply = true
  force_conflicts   = true

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "hoopagent"
      namespace = var.namespace_paragon.id
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "azure.workload.identity/use" = "true"
          }
        }
      }
    }
  })

  depends_on = [helm_release.hoopagent]
}
