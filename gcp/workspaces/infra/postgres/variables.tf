variable "gcp_project_id" {
  description = "The GCP region to deploy resources"
  type        = string
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "network" {
  description = "The Virtual network where our resources will be deployed"
  type        = any
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
  type        = string
}

variable "postgres_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances. Used for higher volume installations."
  type        = bool
}

variable "postgres_tier" {
  description = "The instance type to use for Postgres."
  type        = string
}

variable "postgres_disk_autoresize_limit" {
  description = "Maximum Cloud SQL disk size in GB for autoresize. Null/unset means no Terraform limit (Cloud SQL platform max). 0 is treated as unlimited (GCP default)."
  type        = number
  default     = null
  nullable    = true
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on RDS and S3 resources."
  type        = bool
}

variable "managed_sync_enabled" {
  description = "Whether to create a dedicated Postgres instance for Managed Sync."
  type        = bool
  default     = false
}

variable "agent_os_enabled" {
  description = "Whether to create the dedicated Agent OS Cloud SQL instance."
  type        = bool
  default     = false
}

variable "agent_os_postgres" {
  description = "Optional Agent OS Cloud SQL overrides keyed by instance name (agent_os). Null uses the defaults in postgres-agent-os.tf."
  type = map(object({
    instance_class         = optional(string)
    allocated_storage      = optional(number)
    max_allocated_storage  = optional(number)
    engine_version         = optional(string)
    multi_az               = optional(bool)
    read_replica           = optional(bool)
    replica_instance_class = optional(string)
    storage_type           = optional(string)
  }))
  default  = null
  nullable = true
}

locals {
  postgres_instances = var.postgres_multiple_instances ? merge({
    cerberus = {
      tier = "db-custom-1-3840"
    },
    eventlogs = {
      tier = "db-custom-2-7680"
    },
    hermes = {
      tier = var.postgres_tier
    },
    triggerkit = {
      tier = "db-custom-1-3840"
    },
    zeus = {
      tier = "db-custom-2-7680"
    }
    }, var.managed_sync_enabled ? {
    managed_sync = {
      tier = "db-custom-2-7680"
    }
    } : {}) : {
    paragon = {
      tier = var.postgres_tier
    }
  }
}
