# Event Hubs Namespace with Kafka support
resource "azurerm_eventhub_namespace" "kafka" {
  name                = "${replace(var.workspace, "-", "")}kafka${substr(sha256(var.workspace), 0, 8)}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  sku                      = var.eventhub_namespace_sku
  capacity                 = var.eventhub_capacity
  auto_inflate_enabled     = var.eventhub_auto_inflate_enabled
  maximum_throughput_units = var.eventhub_auto_inflate_enabled ? var.eventhub_maximum_throughput_units : null

  # Network configuration - start with private endpoint only
  # Note: Kafka protocol is automatically enabled for Standard and Premium SKUs
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"

  # Encryption
  local_authentication_enabled = true
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, { Name = "${var.workspace}-kafka" })
}

# Authorization rule for SAS authentication (used by Kafka clients)
resource "azurerm_eventhub_namespace_authorization_rule" "kafka" {
  name                = "${var.workspace}-kafka-auth"
  namespace_name      = azurerm_eventhub_namespace.kafka.name
  resource_group_name = var.resource_group.name

  listen = true
  send   = true
  manage = true
}

# Managed Sync owns the source streams consumed by Agent OS. Event Hubs does not
# support Kafka AdminClient topic creation, so Terraform must provision these entities.
resource "azurerm_eventhub" "managed_sync_agent_os_sources" {
  for_each = var.managed_sync_enabled ? toset([
    "sync.content-record",
    "sync.content-permission",
    "sync.instance-status",
  ]) : toset([])

  name              = each.value
  namespace_id      = azurerm_eventhub_namespace.kafka.id
  partition_count   = var.agent_os_eventhub_partition_count
  message_retention = var.agent_os_eventhub_message_retention
}

# Agent OS owns only the DLT for the Managed Sync status stream.
resource "azurerm_eventhub" "agent_os_dlt" {
  count = var.agent_os_enabled ? 1 : 0

  name              = "sync.instance-status.dlt"
  namespace_id      = azurerm_eventhub_namespace.kafka.id
  partition_count   = var.agent_os_eventhub_partition_count
  message_retention = var.agent_os_eventhub_message_retention
}

# Context Ingest uses one Kafka consumer for all three Managed Sync source topics, so the
# runtime reader credential must be namespace-scoped. Keep it read-only; DLT writes use a
# separate entity-scoped credential below.
resource "azurerm_eventhub_namespace_authorization_rule" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name                = "${substr(var.workspace, 0, 30)}-${substr(md5(var.workspace), 0, 8)}-aos-read"
  namespace_name      = azurerm_eventhub_namespace.kafka.name
  resource_group_name = var.resource_group.name

  listen = true
  send   = false
  manage = false
}

resource "azurerm_eventhub_authorization_rule" "agent_os_dlt_writer" {
  count = var.agent_os_enabled ? 1 : 0

  name                = "${substr(var.workspace, 0, 30)}-${substr(md5(var.workspace), 0, 8)}-aos-dlt-write"
  namespace_name      = azurerm_eventhub_namespace.kafka.name
  eventhub_name       = azurerm_eventhub.agent_os_dlt[0].name
  resource_group_name = var.resource_group.name

  listen = false
  send   = true
  manage = false
}
