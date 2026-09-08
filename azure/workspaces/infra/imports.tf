// The least-privilege bootstrap creates the deterministic main resource group
// before Terraform receives Contributor on that scope. Existing migrated state
// already contains this address, so this import is an idempotent no-op there.
import {
  to = module.network.azurerm_resource_group.main
  id = "/subscriptions/${var.azure_subscription_id}/resourceGroups/${local.workspace}-resources"
}
