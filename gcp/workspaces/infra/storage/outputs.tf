output "storage" {
  value = {
    private_bucket      = google_storage_bucket.app.name
    public_bucket       = google_storage_bucket.cdn.name
    logs_bucket         = google_storage_bucket.logs.name
    auditlogs_bucket    = google_storage_bucket.auditlogs.name
    managed_sync_bucket = var.managed_sync_enabled ? google_storage_bucket.managed_sync[0].name : null
    agent_os_bucket     = var.agent_os_enabled ? google_storage_bucket.agent_os[0].name : null
    # Existing Paragon/Managed Sync SA address; Agent OS uses agent_os_service_account.
    service_account          = google_service_account.storage.email
    agent_os_service_account = var.agent_os_enabled ? google_service_account.agent_os[0].email : null
    private_key              = var.use_storage_account_key ? google_service_account_key.storage[0].private_key : null
    project_id               = var.gcp_project_id
    region                   = var.region
  }
  sensitive = true
}
