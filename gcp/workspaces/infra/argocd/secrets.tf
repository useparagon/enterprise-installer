# Secret Manager secrets for GitOps + OpenObserve credentials + CRD readiness wait.
# All secrets are created inside the module so the argocd_enabled feature flag
# at the module call site is the single gate for all cloud-side ArgoCD resources.

locals {
  secrets_ready = (
    trimspace(var.paragon_domain) != "" &&
    var.docker_username != null && var.docker_username != "" &&
    var.docker_password != null && var.docker_password != ""
  )

  openobserve_credentials = {
    email    = "${random_string.openobserve_email.result}@useparagon.com"
    password = random_password.openobserve_password.result
  }

  docker_config = local.secrets_ready ? jsonencode({
    auths = {
      (var.docker_registry_server) = {
        username = var.docker_username
        password = var.docker_password
        email    = coalesce(var.docker_email, "")
        auth     = base64encode("${var.docker_username}:${var.docker_password}")
      }
    }
  }) : null

  docker_cfg_payload = local.docker_config != null ? jsonencode({
    dockerconfigjson = local.docker_config
  }) : null
}

resource "random_string" "openobserve_email" {
  length  = 12
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "random_password" "openobserve_password" {
  length  = 32
  lower   = true
  numeric = true
  special = false
  upper   = true
}

# Wait for the cluster API to be fully stable before Helm installs attempt
# to apply CRD-backed resources. Triggered by cluster_name so a cluster
# replacement causes the wait to re-run.
resource "time_sleep" "eso_crds" {
  create_duration = "120s"

  triggers = {
    cluster_name = var.cluster_name
  }
}

resource "google_secret_manager_secret" "env" {
  count = local.secrets_ready ? 1 : 0

  secret_id = "${var.workspace}-env"
  project   = var.gcp_project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "env" {
  count = local.secrets_ready ? 1 : 0

  secret      = google_secret_manager_secret.env[0].id
  secret_data = jsonencode(var.env_config)
}

resource "google_secret_manager_secret" "docker_cfg" {
  count = local.secrets_ready ? 1 : 0

  secret_id = "${var.workspace}-docker-cfg"
  project   = var.gcp_project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "docker_cfg" {
  count = local.secrets_ready ? 1 : 0

  secret      = google_secret_manager_secret.docker_cfg[0].id
  secret_data = local.docker_cfg_payload
}

resource "google_secret_manager_secret" "managed_sync" {
  count = local.secrets_ready && var.managed_sync_config != null ? 1 : 0

  secret_id = "${var.workspace}-managed-sync"
  project   = var.gcp_project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "managed_sync" {
  count = local.secrets_ready && var.managed_sync_config != null ? 1 : 0

  secret      = google_secret_manager_secret.managed_sync[0].id
  secret_data = jsonencode(var.managed_sync_config)
}

resource "google_secret_manager_secret" "openobserve" {
  count = local.secrets_ready ? 1 : 0

  secret_id = "${var.workspace}-openobserve"
  project   = var.gcp_project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "openobserve" {
  count = local.secrets_ready ? 1 : 0

  secret = google_secret_manager_secret.openobserve[0].id
  secret_data = jsonencode({
    ZO_ROOT_USER_EMAIL    = local.openobserve_credentials.email
    ZO_ROOT_USER_PASSWORD = local.openobserve_credentials.password
  })
}
