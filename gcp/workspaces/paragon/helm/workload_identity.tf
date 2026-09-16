# Workload Identity IAM bindings
# These bindings allow Kubernetes service accounts to impersonate the GCP service account
# when using Workload Identity
resource "google_service_account_iam_member" "workload_identity_binding" {
  for_each = var.storage_service_account != null ? toset(local.cloud_storage_services) : []

  service_account_id = "projects/${data.google_container_cluster.cluster.project}/serviceAccounts/${var.storage_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${data.google_container_cluster.cluster.project}.svc.id.goog[${kubernetes_namespace_v1.paragon.id}/${each.value}]"
}

# Agent OS pods in the Paragon namespace use the dedicated agent-os KSA/GSA identity.
resource "google_service_account_iam_member" "agent_os_workload_identity" {
  count = var.agent_os_enabled && var.agent_os_service_account != null ? 1 : 0

  service_account_id = "projects/${data.google_container_cluster.cluster.project}/serviceAccounts/${var.agent_os_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${data.google_container_cluster.cluster.project}.svc.id.goog[${kubernetes_namespace_v1.paragon.id}/agent-os]"

  depends_on = [kubernetes_service_account_v1.agent_os]
}
