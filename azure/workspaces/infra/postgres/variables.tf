variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "virtual_network" {
  description = "The virtual network to deploy to."
}

variable "private_subnet" {
  description = "Private subnet accessible only within the virtual network to deploy to."
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
  description = "PostgreSQL instances to deploy. Each key is a logical name (cerberus, eventlogs, hermes, triggerkit, zeus, managed_sync, paragon)."
  type = map(object({
    sku       = string
    redundant = bool
  }))
}

variable "postgres_version" {
  description = "PostgreSQL version (14, 15 or 16)"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

locals {
  postgres_db_names = {
    cerberus     = "cerberus"
    eventlogs    = "eventlogs"
    hermes       = "hermes"
    triggerkit   = "triggerkit"
    zeus         = "zeus"
    managed_sync = "managed_sync"
    paragon      = "postgres"
  }

  postgres_server_names = {
    cerberus     = "${var.workspace}-cerberus"
    eventlogs    = "${var.workspace}-eventlogs"
    hermes       = "${var.workspace}-hermes"
    triggerkit   = "${var.workspace}-triggerkit"
    zeus         = "${var.workspace}-zeus"
    managed_sync = "${var.workspace}-managed-sync"
    paragon      = var.workspace
  }

  postgres_instances = {
    for name, cfg in var.instances : name => {
      name = local.postgres_server_names[name]
      db   = local.postgres_db_names[name]
      ha   = cfg.redundant
      sku  = cfg.sku
    }
  }
}
