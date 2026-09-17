resource "google_redis_instance" "redis" {
  for_each = local.redis_instances

  # name: use full workspace if ≤40 chars, else truncated (locals in variables.tf).
  name           = local.redis_instance_name[each.key]
  display_name   = "${var.workspace}-redis-${each.key}"
  memory_size_gb = each.value.size
  redis_version  = "REDIS_6_X"
  tier           = "STANDARD_HA"

  project                 = var.gcp_project_id
  authorized_network      = var.network.id
  region                  = var.region
  location_id             = var.region_zone
  alternative_location_id = var.region_zone_backup

  auth_enabled            = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"
}

# Agent OS Valkey instances are driven by the workspace-level map so each cache can
# be sized independently from Paragon/Managed Sync Redis.
locals {
  agent_os_valkey_instances = var.agent_os_enabled ? var.agent_os_valkey : {}

  agent_os_valkey_names = {
    for key, _ in local.agent_os_valkey_instances :
    key => key == "cache"
    ? "${substr(replace(var.workspace, "_", "-"), 0, 40)}-aos-vk"
    : "${substr(replace(var.workspace, "_", "-"), 0, 40)}-aos-vk-${substr(replace(key, "_", "-"), 0, 15)}"
  }
}

# Memorystore for Valkey is reached over Private Service Connect. The policy is
# shared by all Agent OS Valkey instances in this subnet/region.
resource "google_network_connectivity_service_connection_policy" "agent_os_valkey" {
  count = length(local.agent_os_valkey_instances) > 0 ? 1 : 0

  name          = "${substr(replace(var.workspace, "_", "-"), 0, 40)}-aos-vk"
  location      = var.region
  service_class = "gcp-memorystore"
  description   = "Agent OS Memorystore for Valkey"
  network       = var.network.id
  project       = var.gcp_project_id

  psc_config {
    subnetworks = [var.private_subnet.id]
  }
}

resource "google_memorystore_instance" "agent_os" {
  for_each = local.agent_os_valkey_instances

  instance_id    = local.agent_os_valkey_names[each.key]
  location       = var.region
  project        = var.gcp_project_id
  engine_version = each.value.engine_version
  node_type      = each.value.node_type
  shard_count    = 1
  replica_count  = each.value.multi_az ? 1 : 0
  mode           = each.value.cluster_enabled ? "CLUSTER" : "CLUSTER_DISABLED"

  desired_auto_created_endpoints {
    network    = var.network.id
    project_id = var.gcp_project_id
  }

  deletion_protection_enabled = !var.disable_deletion_protection
  # Memorystore for Valkey has no AUTH token; clients authenticate with IAM.
  authorization_mode      = "IAM_AUTH"
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  depends_on = [google_network_connectivity_service_connection_policy.agent_os_valkey]
}

locals {
  # PSC auto-connections are created one per service attachment (primary, reader and,
  # in cluster mode, discovery), so select the endpoint by connection type per instance.
  agent_os_valkey_connections = {
    for key, instance in google_memorystore_instance.agent_os :
    key => flatten([
      for endpoint in instance.endpoints :
      flatten([
        for connection in endpoint.connections :
        connection.psc_auto_connection
      ])
    ])
  }

  agent_os_valkey_connection_types = {
    for key, cfg in local.agent_os_valkey_instances :
    key => cfg.cluster_enabled ? "CONNECTION_TYPE_DISCOVERY" : "CONNECTION_TYPE_PRIMARY"
  }

  agent_os_valkey_candidates = {
    for key, connections in local.agent_os_valkey_connections :
    key => [
      for connection in connections :
      connection if connection.connection_type == local.agent_os_valkey_connection_types[key]
    ]
  }

  agent_os_valkey_endpoints = {
    for key, candidates in local.agent_os_valkey_candidates :
    key => length(candidates) > 0 ? candidates[0] : null
  }
}
