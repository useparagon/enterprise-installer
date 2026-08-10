locals {
  eso_sync_triggers = join(",", compact([
    try(kubectl_manifest.external_secret_paragon.uid, null),
    var.docker_cfg_secret_name != null ? try(kubectl_manifest.external_secret_docker[0].uid, null) : null,
    var.openobserve_secret_name != null ? try(kubectl_manifest.external_secret_openobserve[0].uid, null) : null,
    var.managed_sync_secret_name != null ? try(kubectl_manifest.external_secret_managed_sync[0].uid, null) : null,
  ]))
}

resource "time_sleep" "wait_for_eso_core_secrets" {
  create_duration = "90s"

  depends_on = [
    kubectl_manifest.external_secret_paragon,
    kubectl_manifest.external_secret_docker,
  ]

  triggers = {
    external_secrets = local.eso_sync_triggers
  }
}

resource "time_sleep" "wait_for_eso_openobserve" {
  count = var.openobserve_secret_name != null ? 1 : 0

  create_duration = "30s"

  depends_on = [kubectl_manifest.external_secret_openobserve[0]]

  triggers = {
    external_secret = try(kubectl_manifest.external_secret_openobserve[0].uid, null)
  }
}

resource "time_sleep" "wait_for_eso_managed_sync" {
  count = var.managed_sync_secret_name != null ? 1 : 0

  create_duration = "30s"

  depends_on = [kubectl_manifest.external_secret_managed_sync[0]]

  triggers = {
    external_secret = try(kubectl_manifest.external_secret_managed_sync[0].uid, null)
  }
}

resource "terraform_data" "eso_secrets_gate" {
  input = local.eso_sync_triggers

  depends_on = [
    time_sleep.wait_for_eso_core_secrets,
    time_sleep.wait_for_eso_openobserve,
    time_sleep.wait_for_eso_managed_sync,
  ]
}

data "kubernetes_secret" "paragon_secrets" {
  metadata {
    name      = "paragon-secrets"
    namespace = kubernetes_namespace.paragon.id
  }

  depends_on = [terraform_data.eso_secrets_gate]
}

data "kubernetes_secret" "docker_cfg" {
  count = var.docker_cfg_secret_name != null ? 1 : 0

  metadata {
    name      = var.docker_pull_secret_name
    namespace = kubernetes_namespace.paragon.id
  }

  depends_on = [terraform_data.eso_secrets_gate]
}

data "kubernetes_secret" "openobserve_credentials" {
  count = var.openobserve_secret_name != null ? 1 : 0

  metadata {
    name      = "openobserve-credentials"
    namespace = kubernetes_namespace.paragon.id
  }

  depends_on = [terraform_data.eso_secrets_gate]
}

data "kubernetes_secret" "managed_sync_secrets" {
  count = var.managed_sync_secret_name != null ? 1 : 0

  metadata {
    name      = "paragon-managed-sync-secrets"
    namespace = kubernetes_namespace.paragon.id
  }

  depends_on = [terraform_data.eso_secrets_gate]
}
