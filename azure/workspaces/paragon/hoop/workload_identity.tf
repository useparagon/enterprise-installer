# The hoopagent chart has no podLabels. Workload Identity's mutating webhook only
# injects Azure env/token volume when this label is on the pod template.
resource "kubernetes_manifest" "hoopagent_workload_identity_label" {
  count = local.hoop_workload_identity_enabled ? 1 : 0

  manifest = {
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
  }

  field_manager {
    name            = "terraform-workload-identity"
    force_conflicts = true
  }

  computed_fields = [
    "metadata.annotations",
    "metadata.labels",
    "spec.selector",
    "spec.strategy",
    "spec.replicas",
    "spec.template.metadata.annotations",
    "spec.template.spec",
  ]

  depends_on = [helm_release.hoopagent]
}
