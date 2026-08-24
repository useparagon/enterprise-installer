moved {
  from = module.bastion
  to   = module.bastion[0]
}

moved {
  from = module.postgres
  to   = module.postgres[0]
}

moved {
  from = azurerm_key_vault_secret.runtime_postgres
  to   = azurerm_key_vault_secret.runtime_postgres[0]
}

moved {
  from = azurerm_key_vault_secret.runtime_redis
  to   = azurerm_key_vault_secret.runtime_redis[0]
}

moved {
  from = azurerm_key_vault_secret.runtime_redis_managed
  to   = azurerm_key_vault_secret.runtime_redis_managed[0]
}
