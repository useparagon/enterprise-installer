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

# Agent OS cache: dedicated Memorystore for Valkey 7.2, isolated from the Paragon/Managed Sync
# Redis instances above. App env keys stay REDIS_* (Redis-compatible API).

locals {
  agent_os_valkey_config_defaults = {
    node_type       = "STANDARD_SMALL"
    multi_az        = true
    cluster_enabled = false
  }

  # Partial overrides set omitted attributes to null; drop them so defaults survive the merge.
  agent_os_valkey_config = merge(
    local.agent_os_valkey_config_defaults,
    { for key, value in try(var.agent_os_valkey["cache"], {}) : key => value if value != null },
  )

  # Memorystore instance IDs are capped at 63 characters; keep room for the suffix.
  agent_os_valkey_name = "${substr(replace(var.workspace, "_", "-"), 0, 40)}-aos-vk"
}

# Memorystore for Valkey is reached over Private Service Connect, which requires a
# gcp-memorystore service connection policy on the subnet before the instance is created.
resource "google_network_connectivity_service_connection_policy" "agent_os_valkey" {
  count = var.agent_os_enabled ? 1 : 0

  name          = local.agent_os_valkey_name
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
  count = var.agent_os_enabled ? 1 : 0

  instance_id    = local.agent_os_valkey_name
  location       = var.region
  project        = var.gcp_project_id
  engine_version = "VALKEY_7_2"
  node_type      = local.agent_os_valkey_config.node_type
  shard_count    = 1
  replica_count  = local.agent_os_valkey_config.multi_az ? 1 : 0
  mode           = local.agent_os_valkey_config.cluster_enabled ? "CLUSTER" : "CLUSTER_DISABLED"

  desired_auto_created_endpoints {
    network    = var.network.id
    project_id = var.gcp_project_id
  }

  deletion_protection_enabled = !var.disable_deletion_protection
  # Memorystore for Valkey has no AUTH token; clients authenticate with IAM
  # (GSA roles/memorystore.dbConnectionUser + empty REDIS_PASSWORD in app secret).
  authorization_mode      = "IAM_AUTH"
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  depends_on = [google_network_connectivity_service_connection_policy.agent_os_valkey]
}

locals {
  # PSC auto-connections are created one per service attachment (primary, reader and, in
  # cluster mode, discovery), so the endpoint has to be selected by connection type.
  agent_os_valkey_connections = var.agent_os_enabled ? flatten([
    for endpoint in google_memorystore_instance.agent_os[0].endpoints :
    flatten([
      for connection in endpoint.connections :
      connection.psc_auto_connection
    ])
  ]) : []

  # Cluster clients bootstrap from the discovery endpoint; cluster-disabled ones use the primary.
  agent_os_valkey_connection_type = local.agent_os_valkey_config.cluster_enabled ? "CONNECTION_TYPE_DISCOVERY" : "CONNECTION_TYPE_PRIMARY"

  # Never silently fall back to a reader endpoint: writes would fail at runtime.
  agent_os_valkey_candidates = [
    for connection in local.agent_os_valkey_connections :
    connection if connection.connection_type == local.agent_os_valkey_connection_type
  ]

  agent_os_valkey_endpoint = length(local.agent_os_valkey_candidates) > 0 ? local.agent_os_valkey_candidates[0] : null
}
