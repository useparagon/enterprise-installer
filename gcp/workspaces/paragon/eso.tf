locals {
  eso_namespace = "external-secrets"
  eso_sa_name   = "external-secrets"
}

resource "google_service_account" "eso" {
  account_id   = substr(replace("${local.workspace}-eso", "-", ""), 0, 30)
  display_name = "External Secrets Operator"
}

resource "google_project_iam_member" "eso_secret_accessor" {
  project = local.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso.email}"
}

resource "google_service_account_iam_member" "eso_workload_identity" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.gcp_project_id}.svc.id.goog[${local.eso_namespace}/${local.eso_sa_name}]"
}
