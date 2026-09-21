variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "virtual_network" {
  description = "The virtual network to deploy to."
}

variable "private_subnet" {
  description = "Private subnet that can access Kafka."
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "managed_sync_enabled" {
  description = "Whether Managed Sync owns the sync.instance-status Event Hub."
  type        = bool
}

variable "agent_os_enabled" {
  description = "Whether to create Agent OS Event Hubs resources and scoped authorization rules."
  type        = bool
}

variable "agent_os_eventhub_partition_count" {
  description = "Partition count for the Managed Sync instance-status Event Hubs that Agent OS also uses. Partitions cannot be decreased after creation."
  type        = number
}

variable "agent_os_eventhub_message_retention" {
  description = "Retention in days for the Managed Sync instance-status Event Hubs that Agent OS also uses."
  type        = number
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
}

variable "eventhub_namespace_sku" {
  description = "The SKU name for the Event Hubs namespace (Basic, Standard, Premium)."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.eventhub_namespace_sku)
    error_message = "The sku_name must be `Basic`, `Standard`, or `Premium`."
  }
}

variable "eventhub_capacity" {
  description = "The capacity units for the Event Hubs namespace (1-20 for Standard, 1-8 for Premium)."
  type        = number
  default     = 1
  validation {
    condition     = var.eventhub_capacity >= 1 && var.eventhub_capacity <= 20
    error_message = "The capacity must be between 1 and 20."
  }
}

variable "eventhub_auto_inflate_enabled" {
  description = "Whether to enable auto-inflate for the Event Hubs namespace."
  type        = bool
  default     = true
}

variable "eventhub_maximum_throughput_units" {
  description = "The maximum throughput units for auto-inflate (only applicable when auto_inflate_enabled is true)."
  type        = number
  default     = 20
}

