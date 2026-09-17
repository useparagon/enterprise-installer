output "blob" {
  value = {
    name = local.storage_account_name
    id   = azurerm_storage_account.blob.id
    # Same account hosts public (cdn) and private containers; runtime_secrets expects this key.
    public_storage_account_name = local.storage_account_name
    access_key                  = azurerm_storage_account.blob.primary_access_key
    private_container           = azurerm_storage_container.app.name
    public_container            = azurerm_storage_container.cdn.name
    logs_container              = azurerm_storage_container.logs.name
    managed_sync_container      = var.managed_sync_enabled ? azurerm_storage_container.managed_sync[0].name : null
    agent_os_container          = var.agent_os_enabled ? azurerm_storage_container.agent_os[0].name : null
    agent_os_container_id       = var.agent_os_enabled ? azurerm_storage_container.agent_os[0].id : null
    auditlogs_container         = azurerm_storage_container.auditlogs.name
  }
  sensitive = true
}
