output "storage" {
  value = {
    private_bucket      = google_storage_bucket.app.name
    public_bucket       = google_storage_bucket.cdn.name
    logs_bucket         = google_storage_bucket.logs.name
    auditlogs_bucket    = google_storage_bucket.auditlogs.name
    managed_sync_bucket = var.managed_sync_enabled ? google_storage_bucket.managed_sync[0].name : null
    service_account     = google_service_account.storage.email
    private_key         = var.use_storage_account_key ? google_service_account_key.storage[0].private_key : null
    project_id          = var.gcp_project_id
    region              = var.region
  }
  sensitive = true
}
