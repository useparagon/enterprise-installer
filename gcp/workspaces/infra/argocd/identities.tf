resource "google_service_account" "eso" {
  count = local.enabled ? 1 : 0

  account_id   = local.gitops_eso_account_id
  display_name = "External Secrets Operator for ${var.workspace}"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "eso_secret_accessor" {
  count = local.enabled ? 1 : 0

  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso[0].email}"
}

resource "google_service_account_iam_binding" "eso_workload_identity" {
  count = local.enabled ? 1 : 0

  service_account_id = google_service_account.eso[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.gcp_project_id}.svc.id.goog[${local.gitops_eso_namespace}/${local.gitops_eso_sa_name}]",
  ]
}

resource "google_service_account" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  account_id   = local.gitops_external_dns_account_id
  display_name = "external-dns for ${var.workspace}"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "external_dns_dns_admin" {
  count = local.gitops_ingress_enabled ? 1 : 0

  project = var.gcp_project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns[0].email}"
}

resource "google_service_account_iam_binding" "external_dns_workload_identity" {
  count = local.gitops_ingress_enabled ? 1 : 0

  service_account_id = google_service_account.external_dns[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.gcp_project_id}.svc.id.goog[external-dns/external-dns]",
  ]
}
