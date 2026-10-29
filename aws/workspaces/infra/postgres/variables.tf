variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "vpc" {
  description = "The VPC to create resources in."
  type        = any
}

variable "private_subnet" {
  description = "The private subnets within the VPC."
  type        = any
}

variable "rds_postgres_version" {
  description = "Postgres version for the database."
  type        = string
}

variable "rds_restore_from_snapshot" {
  description = "Specifies that RDS instances should be restored from a snapshot."
  type        = bool
}

variable "rds_final_snapshot_enabled" {
  description = "Specifies that RDS instances should perform a final snapshot before being deleted."
  type        = bool
}

variable "agent_os_enabled" {
  description = "Whether Agent OS is enabled (provisions logical context/tools databases on the agent_os instance)."
  type        = bool
}

# Fully resolved per-instance catalog from the root workspace; no defaults in this module.
variable "postgres_instances" {
  description = "PostgreSQL RDS instances keyed by logical workload name."
  type = map(object({
    identifier                          = string
    database_name                       = string
    port                                = number
    instance_class                      = string
    allocated_storage                   = number
    max_allocated_storage               = number
    engine_version                      = string
    multi_az                            = bool
    availability_zone                   = optional(string)
    read_replica                        = bool
    replica_instance_class              = string
    storage_type                        = string
    iops                                = optional(number)
    storage_throughput                  = optional(number)
    backup_retention_days               = number
    backup_window                       = string
    maintenance_window                  = string
    enabled_cloudwatch_logs_exports     = list(string)
    monitoring_interval                 = number
    performance_insights_enabled        = bool
    performance_insights_retention_days = number
    ca_cert_identifier                  = string
    auto_minor_version_upgrade          = bool
    allow_major_version_upgrade         = bool
    apply_immediately                   = bool
    deletion_protection                 = bool
    kms_key_arn                         = optional(string)
    tags                                = map(string)
  }))
}

variable "migrated_passwords" {
  description = "Override credentials to preserve complexity conventions when migrating from legacy workspaces"
  type        = map(string)
  default     = {}
}
