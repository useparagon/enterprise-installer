resource "google_compute_global_address" "paragon" {
  name          = "${var.workspace}-global-psconnect-ip"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = var.network.id
  project       = var.gcp_project_id
  prefix_length = 16
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.paragon.name]
}

resource "google_sql_database_instance" "paragon" {
  for_each = local.postgres_instances

  name                = "${var.workspace}-${replace(each.key, "_", "-")}"
  project             = var.gcp_project_id
  region              = var.region
  database_version    = "POSTGRES_14"
  deletion_protection = !var.disable_deletion_protection

  settings {
    disk_autoresize = true
    tier            = each.value.tier

    backup_configuration {
      binary_log_enabled = false
    }

    database_flags {
      name  = "max_connections"
      value = 5000
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "paragon" {
  for_each = local.postgres_instances

  name       = each.key
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[each.key].name
  depends_on = [google_sql_user.postgres_user]
}

resource "random_string" "postgres_root_username" {
  for_each = local.postgres_instances

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "postgres_root_password" {
  for_each = local.postgres_instances

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "postgres_user" {
  for_each = local.postgres_instances

  name     = random_string.postgres_root_username[each.key].result
  password = random_password.postgres_root_password[each.key].result
  instance = google_sql_database_instance.paragon[each.key].name
  project  = var.gcp_project_id
}

locals {
  openfga_instance_key        = var.managed_sync_enabled ? (contains(keys(local.postgres_instances), "managed_sync") ? "managed_sync" : "paragon") : null
  managed_sync_extra_db_names = toset(local.openfga_instance_key != null ? ["sync_project", "sync_instance"] : [])
}

resource "google_sql_database" "openfga" {
  count = local.openfga_instance_key != null ? 1 : 0

  name       = "openfga"
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[local.openfga_instance_key].name
  depends_on = [google_sql_user.openfga]
}

# managed_sync: DBs and users in TF (destroy order: drop DBs before users).
resource "google_sql_database" "managed_sync_extra" {
  for_each = local.managed_sync_extra_db_names

  name       = each.value
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.paragon[local.openfga_instance_key].name
  depends_on = [google_sql_user.openfga, google_sql_user.sync_project, google_sql_user.sync_instance]
}

resource "random_string" "openfga_username" {
  count = var.managed_sync_enabled ? 1 : 0

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "openfga_password" {
  count = var.managed_sync_enabled ? 1 : 0

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "openfga" {
  count = var.managed_sync_enabled ? 1 : 0

  name     = random_string.openfga_username[0].result
  password = random_password.openfga_password[0].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}

resource "random_string" "managed_sync_db_username" {
  for_each = local.managed_sync_extra_db_names

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "managed_sync_db_password" {
  for_each = local.managed_sync_extra_db_names

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "sync_project" {
  count = var.managed_sync_enabled ? 1 : 0

  name     = random_string.managed_sync_db_username["sync_project"].result
  password = random_password.managed_sync_db_password["sync_project"].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}

resource "google_sql_user" "sync_instance" {
  count = var.managed_sync_enabled ? 1 : 0

  name     = random_string.managed_sync_db_username["sync_instance"].result
  password = random_password.managed_sync_db_password["sync_instance"].result
  instance = google_sql_database_instance.paragon[local.openfga_instance_key].name
  project  = var.gcp_project_id
}


# Agent OS Postgres. Dedicated Cloud SQL instance so the Paragon/Managed Sync instance map above
# keeps its resource addresses; hosts the `context` and `tools` logical databases.

locals {
  agent_os_postgres_config_defaults = {
    instance_class         = "db-custom-2-4096"
    allocated_storage      = 100
    max_allocated_storage  = 1000
    engine_version         = "POSTGRES_16"
    multi_az               = true
    read_replica           = false
    replica_instance_class = "db-custom-1-3840"
    storage_type           = "PD_SSD"
  }

  # Partial overrides set omitted attributes to null; drop them so defaults survive the merge.
  agent_os_postgres_config = merge(
    local.agent_os_postgres_config_defaults,
    { for key, value in try(var.agent_os_postgres["agent_os"], {}) : key => value if value != null },
  )

  agent_os_postgres_name = "${var.workspace}-agent-os"
  agent_os_databases     = var.agent_os_enabled ? toset(["context", "tools"]) : toset([])
}

check "agent_os_postgres_storage" {
  assert {
    condition = (
      local.agent_os_postgres_config.max_allocated_storage >= 100 &&
      local.agent_os_postgres_config.max_allocated_storage >= local.agent_os_postgres_config.allocated_storage
    )
    error_message = "Agent OS Postgres max_allocated_storage must be at least 100 GiB and >= allocated_storage."
  }
}

resource "google_sql_database_instance" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name                = local.agent_os_postgres_name
  project             = var.gcp_project_id
  region              = var.region
  database_version    = local.agent_os_postgres_config.engine_version
  deletion_protection = !var.disable_deletion_protection

  settings {
    tier                  = local.agent_os_postgres_config.instance_class
    availability_type     = local.agent_os_postgres_config.multi_az ? "REGIONAL" : "ZONAL"
    disk_size             = local.agent_os_postgres_config.allocated_storage
    disk_autoresize       = true
    disk_autoresize_limit = local.agent_os_postgres_config.max_allocated_storage
    disk_type             = local.agent_os_postgres_config.storage_type

    backup_configuration {
      enabled    = true
      start_time = "06:00"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    insights_config {
      query_insights_enabled = true
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database_instance" "agent_os_replica" {
  count = var.agent_os_enabled && local.agent_os_postgres_config.read_replica ? 1 : 0

  name                 = "${local.agent_os_postgres_name}-replica"
  project              = var.gcp_project_id
  region               = var.region
  database_version     = local.agent_os_postgres_config.engine_version
  master_instance_name = google_sql_database_instance.agent_os[0].name
  deletion_protection  = !var.disable_deletion_protection

  settings {
    tier      = local.agent_os_postgres_config.replica_instance_class
    disk_type = local.agent_os_postgres_config.storage_type

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
  }
}

resource "random_string" "agent_os_root_username" {
  count = var.agent_os_enabled ? 1 : 0

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "agent_os_root_password" {
  count = var.agent_os_enabled ? 1 : 0

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "agent_os_root" {
  count = var.agent_os_enabled ? 1 : 0

  name     = random_string.agent_os_root_username[0].result
  password = random_password.agent_os_root_password[0].result
  instance = google_sql_database_instance.agent_os[0].name
  project  = var.gcp_project_id
}

resource "random_string" "agent_os_app_username" {
  for_each = local.agent_os_databases

  length  = 16
  lower   = true
  upper   = true
  numeric = false
  special = false
}

resource "random_password" "agent_os_app_password" {
  for_each = local.agent_os_databases

  length  = 32
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_sql_user" "agent_os_app" {
  for_each = local.agent_os_databases

  name     = random_string.agent_os_app_username[each.key].result
  password = random_password.agent_os_app_password[each.key].result
  instance = google_sql_database_instance.agent_os[0].name
  project  = var.gcp_project_id
}

# Destroy order: drop the databases before the users that own objects in them.
resource "google_sql_database" "agent_os" {
  for_each = local.agent_os_databases

  name       = each.value
  project    = var.gcp_project_id
  instance   = google_sql_database_instance.agent_os[0].name
  depends_on = [google_sql_user.agent_os_app]
}
