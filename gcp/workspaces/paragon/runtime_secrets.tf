locals {
  runtime_secret_names = {
    env             = "${local.workspace}-env"
    docker_cfg      = "${local.workspace}-docker-cfg"
    managed_sync    = "${local.workspace}-managed-sync"
    openobserve     = "${local.workspace}-openobserve"
    openobserve_gcs = "${local.workspace}-openobserve-gcs"
  }
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
  count     = local.gcp_creds != null ? 1 : 0
  secret_id = local.runtime_secret_names.openobserve_gcs

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openobserve_gcs" {
  count       = local.gcp_creds != null ? 1 : 0
  secret      = google_secret_manager_secret.openobserve_gcs[0].id
  secret_data = jsonencode({ "creds.json" = local.gcp_creds })
}
