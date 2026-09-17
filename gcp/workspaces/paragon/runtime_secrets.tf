locals {
  runtime_secret_names = {
    env             = "${local.workspace}-env"
    docker_cfg      = "${local.workspace}-docker-cfg"
    managed_sync    = "${local.workspace}-managed-sync"
    openobserve     = "${local.workspace}-openobserve"
    openobserve_gcs = "${local.workspace}-openobserve-gcs"
  }

  # Plan-known storage auth mode. Do not gate count on decoded GSM payload
  # (`local.gcp_creds != null`), which is unknown until apply when
  # infra-output.json is not supplied. WIF only has a storage SA key when
  # infra set use_storage_account_key; static JSON creds always supply HMAC-style JSON.
  openobserve_gcs_enabled = var.use_storage_account_key || !var.gcp_assume_role
}

resource "google_secret_manager_secret" "env" {
  secret_id = local.runtime_secret_names.env

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "env" {
  secret      = google_secret_manager_secret.env.id
  secret_data = jsonencode(local.helm_secret_values)

  lifecycle {
    precondition {
      condition     = length(local.chart_service_inputs) > 0
      error_message = "No charts/**/files/service-inputs.json under ${path.root}/charts. Run ./prepare.sh -p gcp before apply so secretKeys/envKeys can be classified."
    }
    precondition {
      condition     = length(local.helm_secret_values) > 0
      error_message = "Paragon env secret would be empty after chart secretKeys split. Confirm prepare.sh charts and infra-backed helm_values contain postgres/redis credentials."
    }
  }
}

resource "google_secret_manager_secret" "docker_cfg" {
  # Skip when create_docker_pull_secret=false (Artifactory/proxy: pre-provisioned k8s secret).
  count = var.create_docker_pull_secret && var.docker_username != null && var.docker_password != null ? 1 : 0

  secret_id = local.runtime_secret_names.docker_cfg

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "docker_cfg" {
  count = var.create_docker_pull_secret && var.docker_username != null && var.docker_password != null ? 1 : 0

  secret = google_secret_manager_secret.docker_cfg[0].id
  secret_data = jsonencode({
    dockerconfigjson = jsonencode({
      auths = {
        (var.docker_registry_server) = {
          username = var.docker_username
          password = var.docker_password
          email    = var.docker_email
          auth     = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  })
}

resource "google_secret_manager_secret" "managed_sync" {
  count     = var.managed_sync_enabled ? 1 : 0
  secret_id = local.runtime_secret_names.managed_sync

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "managed_sync" {
  count       = var.managed_sync_enabled ? 1 : 0
  secret      = google_secret_manager_secret.managed_sync[0].id
  secret_data = jsonencode(module.managed_sync_config[0].config)
}

# Agent OS follows the Managed Sync flow on GCP: infra publishes resource-derived
# values in its handoff, and the paragon workspace owns the final secrets consumed by ESO.
resource "google_secret_manager_secret" "agent_os_app" {
  count     = var.agent_os_enabled ? 1 : 0
  secret_id = local.agent_os_app_secret_name

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "agent_os_app" {
  count  = var.agent_os_enabled ? 1 : 0
  secret = google_secret_manager_secret.agent_os_app[0].id
  secret_data = jsonencode(merge(
    local.agent_os_handoff.app_config,
    var.agent_os_app_config,
  ))
}

resource "google_secret_manager_secret" "agent_os_admin" {
  count     = var.agent_os_enabled ? 1 : 0
  secret_id = local.agent_os_admin_secret_name

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "agent_os_admin" {
  count  = var.agent_os_enabled ? 1 : 0
  secret = google_secret_manager_secret.agent_os_admin[0].id
  secret_data = jsonencode(merge(
    local.agent_os_handoff.admin_config,
    var.agent_os_admin_config,
  ))
}

resource "google_secret_manager_secret" "agent_os_vendor" {
  count     = var.agent_os_enabled ? 1 : 0
  secret_id = local.agent_os_vendor_secret_name

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "agent_os_vendor" {
  count       = var.agent_os_enabled ? 1 : 0
  secret      = google_secret_manager_secret.agent_os_vendor[0].id
  secret_data = jsonencode(var.agent_os_vendor_config)
}

resource "google_secret_manager_secret" "openobserve" {
  count     = 1
  secret_id = local.runtime_secret_names.openobserve

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openobserve" {
  count  = 1
  secret = google_secret_manager_secret.openobserve[0].id
  secret_data = jsonencode({
    ZO_ROOT_USER_EMAIL    = local.openobserve_email
    ZO_ROOT_USER_PASSWORD = local.openobserve_password
  })
}

resource "google_secret_manager_secret" "openobserve_gcs" {
  count     = local.openobserve_gcs_enabled ? 1 : 0
  secret_id = local.runtime_secret_names.openobserve_gcs

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openobserve_gcs" {
  count       = local.openobserve_gcs_enabled ? 1 : 0
  secret      = google_secret_manager_secret.openobserve_gcs[0].id
  secret_data = jsonencode({ "creds.json" = local.gcp_creds })

  lifecycle {
    precondition {
      condition     = local.gcp_creds != null && local.gcp_creds != ""
      error_message = "OpenObserve GCS credentials are enabled but the storage key is missing. Set use_storage_account_key=true in both the infra and paragon workspaces so infra mints the storage SA key, or leave it false under WIF so OpenObserve uses Workload Identity instead of ZO_S3_ACCESS_KEY."
    }
  }
}
