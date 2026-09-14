// The least-privilege bootstrap creates the deterministic main resource group
// before Terraform receives Contributor on that scope. Existing migrated state
// already contains this address, so this import is an idempotent no-op there.
// azure_subscription_id is a sensitive variable, and interpolating it taints
// the whole string; import ids may not be sensitive. local.workspace unwraps
// the same way for its own hash of the subscription ID.
import {
  to = module.network.azurerm_resource_group.main
  id = nonsensitive("/subscriptions/${var.azure_subscription_id}/resourceGroups/${local.workspace}-resources")
}
