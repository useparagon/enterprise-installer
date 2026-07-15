resource "random_string" "node_pool" {
  for_each = local.nodes

  length  = 6
  special = false
  numeric = false
  lower   = true
  upper   = false
  keepers = {
    workspace          = var.workspace
    vm_size            = each.value.vm_size
    kubernetes_version = var.k8s_version
  }
}

locals {
  cluster_name = "${var.workspace}-cluster"

  nodes = merge(
    var.k8s_spot_instance_percent < 100 ? {
      ondemand = {
        min_count = ceil(var.k8s_min_node_count * (1 - (var.k8s_spot_instance_percent / 100)))
        max_count = ceil(var.k8s_max_node_count * (1 - (var.k8s_spot_instance_percent / 100)))
        vm_size   = var.k8s_ondemand_node_instance_type
      }
    } : {},
    var.k8s_spot_instance_percent > 0 ? {
      spot = {
        min_count = floor(var.k8s_min_node_count * (var.k8s_spot_instance_percent / 100))
        max_count = ceil(var.k8s_max_node_count * (var.k8s_spot_instance_percent / 100))
        vm_size   = var.k8s_spot_node_instance_type
      }
    } : {}
  )
}

# AKS rejects userAssignedNATGateway until the node subnet has a NAT gateway associated.
# The cluster only references private_subnet.id (which pre-exists), so without this hook
# Terraform can update outbound_type in parallel with the new association resource.
resource "terraform_data" "nat_gateway_ready" {
  count = var.k8s_outbound_type == "userAssignedNATGateway" ? 1 : 0

  input = var.private_subnet_nat_gateway_id
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = local.cluster_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  dns_prefix          = local.cluster_name
  kubernetes_version  = var.k8s_version
  node_resource_group = "${local.cluster_name}-nodes"
  sku_tier            = var.k8s_sku_tier

  # disable automatic upgrades - manual upgrades only
  node_os_upgrade_channel = "Unmanaged"

  # NOTE: The configuration for the cluster can't change at all
  # We're intentionally setting very low settings.
  # This way, we can instead reconfigure the node pools using `azurerm_kubernetes_cluster_node_pool` resource.
  default_node_pool {
    name       = "default"
    node_count = 1
    # intentionally setting cheapest usable node pool which costs ~ $30 / mo
    # while there are cheaper options, the minimum requirements for this are 2 cpu and 4gb memory
    # https://azureprice.net/
    vm_size              = var.k8s_default_node_pool_vm_size
    type                 = "VirtualMachineScaleSets"
    auto_scaling_enabled = false
    vnet_subnet_id       = var.private_subnet.id

    # Configure upgrade settings to minimize disruption from automatic node image upgrades
    upgrade_settings {
      max_surge = "1"
    }
  }

  network_profile {
    network_plugin      = var.k8s_network_plugin
    network_plugin_mode = var.k8s_network_plugin_mode
    pod_cidr            = var.k8s_pod_cidr
    dns_service_ip      = var.k8s_dns_service_ip
    service_cidr        = var.k8s_service_cidr
    outbound_type       = var.k8s_outbound_type
    load_balancer_sku   = var.k8s_load_balancer_sku
    network_policy      = var.k8s_network_policy
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  depends_on = [terraform_data.nat_gateway_ready]

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings
    ]
  }
}

# required for subnet join when provisioning LoadBalancers / updating VMSS.
# skip_service_principal_aad_check is intentionally omitted: changing it on an
# existing assignment is ForceNew and azurerm errors with "doesn't support update".
# For greenfield AAD lag, re-run apply (or wait briefly) rather than toggling that flag.
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = var.private_subnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.cluster.identity[0].principal_id
}

# cloud-provider-azure updates security rules on the subnet's NSG when syncing
# LoadBalancers; Network Contributor on the subnet alone does not cover the NSG.
resource "azurerm_role_assignment" "aks_nsg_network_contributor" {
  scope                = var.aks_nsg_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.cluster.identity[0].principal_id
}

# created as a separate resource so config can be updated
# if `default_node_pool` is updated in the `azurerm_kubernetes_cluster`,
# all terraform updates fail
resource "azurerm_kubernetes_cluster_node_pool" "pool" {
  for_each = local.nodes

  # must begin with a lowercase letter, contain only lowercase letters and numbers and be between 1 and 12 characters
  name = each.key == "ondemand" ? "onde${random_string.node_pool[each.key].result}" : "spt${random_string.node_pool[each.key].result}"

  auto_scaling_enabled  = true
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  max_count             = each.value.max_count
  min_count             = each.value.min_count
  orchestrator_version  = var.k8s_version
  os_sku                = "Ubuntu"
  os_type               = "Linux"
  tags                  = merge(var.tags, { Name = each.key })
  vm_size               = each.value.vm_size
  vnet_subnet_id        = var.private_subnet.id

  # TODO add spot support but would require tolerations to be added to the pods
  # tolerations:
  # - key: kubernetes.azure.com/scalesetpriority
  #   operator: Equal
  #   value: spot
  #   effect: NoSchedule
  priority = "Regular" # each.key == "ondemand" ? "Regular" : "Spot"

  node_labels = {
    "useparagon.com/capacityType" = each.key
  }

  # Configure upgrade settings to minimize disruption from automatic node image upgrades
  upgrade_settings {
    max_surge = "1"
  }

  depends_on = [
    azurerm_role_assignment.aks_network_contributor,
    azurerm_role_assignment.aks_nsg_network_contributor,
  ]

  # Ensure new nodes are created before old ones are destroyed
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      upgrade_settings
    ]
  }
}
