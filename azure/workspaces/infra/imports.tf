// Greenfield creates the resource group through module.network normally.
// Enable this import only when the bootstrap has already created the group
// outside Terraform (for example, least-privilege Contributor scope setup).
// Existing deployments that already track this resource do not need an import.
import {
  for_each = var.import_existing_resource_group ? { main = nonsensitive("/subscriptions/${var.azure_subscription_id}/resourceGroups/${local.workspace}-resources") } : {}
  to       = module.network.azurerm_resource_group.main
  id       = each.value
}
