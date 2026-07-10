output "config" {
  value = {
    for key, value in local.managed_sync_secrets :
    key => value
    if value != null
  }
}
