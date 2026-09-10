# private bucket
resource "google_storage_bucket" "app" {
  name          = "${var.workspace}-app"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection
}

resource "google_storage_bucket_iam_member" "app" {
  bucket = google_storage_bucket.app.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.storage.email}"
}

# CDN bucket (private; public asset URLs must use your app/proxy base URL in Helm)
resource "google_storage_bucket" "cdn" {
  name          = "${var.workspace}-cdn"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "cdn" {
  bucket = google_storage_bucket.cdn.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.storage.email}"
}

# logs bucket
resource "google_storage_bucket" "logs" {
  name          = "${var.workspace}-logs"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection
}

resource "google_storage_bucket_iam_member" "logs" {
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.storage.email}"
}

# audit logs bucket
resource "google_storage_bucket" "auditlogs" {
  name          = "${var.workspace}-auditlogs"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection

  versioning {
    enabled = true
  }

  retention_policy {
    retention_period = var.auditlogs_retention_days * 86400
    is_locked        = var.auditlogs_lock_enabled
  }
}

resource "google_storage_bucket_iam_member" "auditlogs" {
  bucket = google_storage_bucket.auditlogs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.storage.email}"
}

# Agent OS bucket for parsed documents and Lance index data.
# Workload Identity (no static key) reaches this bucket and IAM-auth Valkey.
resource "google_storage_bucket" "agent_os" {
  count         = var.agent_os_enabled ? 1 : 0
  name          = "${var.workspace}-agent-os"
  location      = var.region
  project       = var.gcp_project_id
  storage_class = "STANDARD"
  force_destroy = var.disable_deletion_protection

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# Dedicated GSA for Agent OS pods; account_id must stay within GCP's 6–30 char limit.
resource "google_service_account" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  project      = var.gcp_project_id
  account_id   = "aos-${substr(md5(var.workspace), 0, 8)}"
  display_name = "Agent OS (${var.workspace})"
  description  = "Workload Identity identity for Agent OS GCS and Valkey IAM auth."
}

resource "google_storage_bucket_iam_member" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  bucket = google_storage_bucket.agent_os[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.agent_os[0].email}"
}

# Bucket metadata (e.g. storage.buckets.get) used by GCS clients; scoped to this bucket only.
resource "google_storage_bucket_iam_member" "agent_os_bucket_reader" {
  count = var.agent_os_enabled ? 1 : 0

  bucket = google_storage_bucket.agent_os[0].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.agent_os[0].email}"
}

# Memorystore for Valkey IAM_AUTH: renewable tokens via this GSA (no REDIS_PASSWORD).
resource "google_project_iam_member" "agent_os_valkey" {
  count = var.agent_os_enabled ? 1 : 0

  project = var.gcp_project_id
  role    = "roles/memorystore.dbConnectionUser"
  member  = "serviceAccount:${google_service_account.agent_os[0].email}"
}
