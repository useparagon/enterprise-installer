# GSAs for ESO and external-dns with Workload Identity bindings.
# Created inside the module so all ArgoCD cloud resources are encapsulated
# behind the argocd_enabled feature flag.

locals {
  gitops_eso_namespace   = "external-secrets"
  gitops_eso_sa_name     = "external-secrets"
  gitops_ingress_enabled = trimspace(var.paragon_domain) != ""

  # Safe truncation for GSA account_id (max 30 chars). Strip trailing dash.
  gitops_eso_account_id          = replace(substr("${var.workspace}-eso", 0, 30), "/-$/", "")
  gitops_external_dns_account_id = replace(substr("${var.workspace}-edns", 0, 30), "/-$/", "")
}

# ---------------------------------------------------------------------------
# ESO GSA
# ---------------------------------------------------------------------------

resource "google_service_account" "eso" {
  account_id   = local.gitops_eso_account_id
  display_name = "External Secrets Operator for ${var.workspace}"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "eso_secret_accessor" {
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso.email}"
}

resource "google_service_account_iam_binding" "eso_workload_identity" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.gcp_project_id}.svc.id.goog[${local.gitops_eso_namespace}/${local.gitops_eso_sa_name}]",
  ]
}

# ---------------------------------------------------------------------------
# external-dns GSA
# ---------------------------------------------------------------------------

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
