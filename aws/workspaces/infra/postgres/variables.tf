variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "vpc" {
  description = "The VPC to create resources in."
}

variable "public_subnet" {
  description = "The public subnets within the VPC."
}

variable "private_subnet" {
  description = "The private subnets within the VPC."
}

variable "availability_zones" {
  description = "The AWS zones that are currently availabile."
}

variable "rds_postgres_version" {
  description = "Postgres version for the database."
  type        = string
}

variable "rds_instance_class" {
  description = "The RDS instance class type used for Postgres."
}

variable "rds_managed_sync_instance_class" {
  description = "The RDS instance class type used for the managed sync Postgres instance."
  type        = string
}

variable "rds_gp3_iops" {
  description = "gp3 provisioned IOPS for all RDS instances. Null uses size-based baseline (3000 below 400 GiB, 12000 at/above)."
  type        = number
  default     = null
  nullable    = true
}

variable "rds_gp3_storage_throughput" {
  description = "gp3 throughput (MiB/s). Null uses size-based baseline (125 below 400 GiB, 500 at/above). Must form a valid pair with rds_gp3_iops when overriding."
  type        = number
  default     = null
  nullable    = true
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage (GiB) for each Postgres RDS instance."
  type        = number
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage (GiB) for autoscaling on each Postgres RDS instance."
  type        = number
}

variable "disable_deletion_protection" {
  description = "Whether to disable deletion protection."
  type        = bool
}

variable "rds_multi_az" {
  description = "Whether or not multi-az is enabled."
  type        = bool
}

variable "rds_multiple_instances" {
  description = "Whether or not to create multiple Postgres instances."
  type        = bool
}

variable "rds_restore_from_snapshot" {
  description = "Specifies that RDS instances should be restored from a snapshot."
  type        = bool
}

variable "rds_final_snapshot_enabled" {
  description = "Specifies that RDS instances should perform a final snapshot before being deleted."
  type        = bool
}

variable "managed_sync_enabled" {
  description = "Whether to enable managed sync."
  type        = bool
}

variable "agent_os_enabled" {
  description = "Whether to create the dedicated Agent OS Postgres instance."
  type        = bool
  default     = false
}

variable "agent_os_kms_key_arn" {
  description = "KMS key ARN used to encrypt the Agent OS Postgres instance."
  type        = string
  default     = null
}

variable "agent_os_postgres" {
  description = "Optional Agent OS Postgres overrides keyed by instance name (agent_os). Null uses the defaults in rds-agent-os.tf."
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

  validation {
    condition = var.agent_os_postgres == null ? true : alltrue([
      for _, cfg in var.agent_os_postgres :
      coalesce(cfg.max_allocated_storage, 1000) >= 100 &&
      coalesce(cfg.max_allocated_storage, 1000) >= ceil(coalesce(cfg.allocated_storage, 100) * 1.1)
    ])
    error_message = "Agent OS Postgres max_allocated_storage must be at least 100 GiB and at least 10% greater than allocated_storage."
  }

  validation {
    condition = var.agent_os_postgres == null ? true : alltrue([
      for _, cfg in var.agent_os_postgres :
      contains(["gp2", "gp3"], coalesce(cfg.storage_type, "gp3"))
    ])
    error_message = "Agent OS Postgres storage_type must be gp2 or gp3."
  }
}

variable "migrated_passwords" {
  description = "Override credentials to preserve complexity conventions when migrating from legacy workspaces"
  type        = map(string)
  default     = {}
}

locals {
  postgres_instances = var.rds_multiple_instances ? merge({
    cerberus = {
      name = "${var.workspace}-cerberus"
      size = "db.t4g.micro"
      db   = "cerberus"
    }
    eventlogs = {
      name = "${var.workspace}-eventlogs"
      size = "db.t4g.small"
      db   = "eventlogs"
    }
    hermes = {
      name = "${var.workspace}-hermes"
      size = var.rds_instance_class
      db   = "hermes"
    }
    triggerkit = {
      name = "${var.workspace}-triggerkit"
      size = "db.t4g.micro"
      db   = "triggerkit"
    }
    zeus = {
      name = "${var.workspace}-zeus"
      size = "db.t4g.small"
      db   = "zeus"
    }
    }, var.managed_sync_enabled ? {
    managed_sync = {
      name = "${var.workspace}-managed-sync"
      size = var.rds_managed_sync_instance_class
      db   = "managed_sync"
    }
    } : {}) : {
    paragon = {
      name = "${var.workspace}"
      size = var.rds_instance_class
      db   = "postgres"
    }
  }
}
