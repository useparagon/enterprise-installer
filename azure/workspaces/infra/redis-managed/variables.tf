variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "virtual_network" {
  description = "The virtual network to deploy to."
}

variable "private_subnet" {
  description = "Private subnet that can access Redis."
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
}

variable "instances" {
  description = "Managed Redis instances to deploy. Each key is a logical name (cache, queue, system, managed-sync). Values are merged with workspace defaults before apply."
  type = map(object({
    sku                   = string
    ha_enabled            = bool
    cluster_enabled       = bool
    persistence_mode      = optional(string)
    persistence_frequency = optional(string)
  }))
}

variable "clustering_policy" {
  description = "Clustering policy when cluster_enabled is true."
  type        = string
  default     = "OSSCluster"

  validation {
    condition     = contains(["OSSCluster", "EnterpriseCluster", "NoCluster"], var.clustering_policy)
    error_message = "clustering_policy must be OSSCluster, EnterpriseCluster, or NoCluster."
  }
}

variable "public_network_access" {
  description = "Public network access (Disabled recommended with private endpoints)."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.public_network_access)
    error_message = "public_network_access must be Enabled or Disabled."
  }
}

variable "export_storage_enabled" {
  description = "Create a storage account and grant each instance system-assigned identity access for RDB export (run export via Azure CLI or portal)."
  type        = bool
  default     = false
}

variable "export_storage_replication_type" {
  description = "Replication type for the optional export storage account."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.export_storage_replication_type)
    error_message = "export_storage_replication_type must be a valid Azure storage replication type."
  }
}

variable "export_storage_container_name" {
  description = "Blob container name for RDB export files."
  type        = string
  default     = "redis-export"
}

locals {
  redis_instances = {
    for name, cfg in var.instances : name => {
      sku                       = cfg.sku
      cluster                   = cfg.cluster_enabled == true
      high_availability_enabled = cfg.ha_enabled == true
      clustering_policy         = cfg.cluster_enabled == true ? var.clustering_policy : "NoCluster"
      rdb_backup_frequency = cfg.persistence_mode == "rdb" ? (
        cfg.persistence_frequency != null ? cfg.persistence_frequency : "1h"
      ) : null
      aof_backup_frequency = cfg.persistence_mode == "aof" ? "1s" : null
    }
  }
}
