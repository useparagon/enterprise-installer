# Object-storage access identity (formerly named "minio"). Renamed to "storage" when MinIO
# was retired (PARA-21646); the account_id is immutable and intentionally left as
# "minio-root-user" to avoid destroying/recreating the live service account and its key.
resource "google_service_account" "storage" {
  account_id   = "minio-root-user"
  display_name = "Storage"
  description  = "Allows the application to read and write to Google Cloud Storage."
  project      = var.gcp_project_id
}

resource "google_service_account_key" "storage" {
  count = var.use_storage_account_key ? 1 : 0

  service_account_id = google_service_account.storage.name
}

moved {
  from = google_service_account.minio
  to   = google_service_account.storage
}

moved {
  from = google_service_account_key.minio
  to   = google_service_account_key.storage
}
