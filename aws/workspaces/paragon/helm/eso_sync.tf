locals {
  eso_sync_triggers = var.install_external_secrets ? join(",", compact([
    try(kubectl_manifest.external_secret_paragon[0].uid, null),
    try(kubectl_manifest.external_secret_docker[0].uid, null),
    var.openobserve_secret_name != null ? try(kubectl_manifest.external_secret_openobserve[0].uid, null) : null,
    var.managed_sync_secret_name != null ? try(kubectl_manifest.external_secret_managed_sync[0].uid, null) : null,
  ])) : var.runtime_secrets_ready
}

resource "time_sleep" "wait_for_eso_core_secrets" {
  count = var.install_external_secrets ? 1 : 0

  create_duration = "90s"

  depends_on = [
    kubectl_manifest.external_secret_paragon[0],
    kubectl_manifest.external_secret_docker[0],
  ]

  triggers = {
    external_secrets = local.eso_sync_triggers
  }
}

resource "time_sleep" "wait_for_eso_openobserve" {
  count = var.install_external_secrets && var.openobserve_secret_name != null ? 1 : 0

  create_duration = "30s"

  depends_on = [kubectl_manifest.external_secret_openobserve[0]]

  triggers = {
    external_secret = try(kubectl_manifest.external_secret_openobserve[0].uid, null)
  }
}

resource "time_sleep" "wait_for_eso_managed_sync" {
  count = var.install_external_secrets && var.managed_sync_secret_name != null ? 1 : 0

  create_duration = "30s"

  depends_on = [kubectl_manifest.external_secret_managed_sync[0]]

  triggers = {
    external_secret = try(kubectl_manifest.external_secret_managed_sync[0].uid, null)
  }
}

resource "time_sleep" "wait_for_gitops_secrets" {
  count = var.install_external_secrets ? 0 : 1

  create_duration = "30s"

  triggers = {
    runtime_secrets_ready = var.runtime_secrets_ready
  }
}

resource "terraform_data" "eso_secrets_gate" {
  input = local.eso_sync_triggers

  depends_on = [
    time_sleep.wait_for_eso_core_secrets,
    time_sleep.wait_for_gitops_secrets,
    time_sleep.wait_for_eso_openobserve,
    time_sleep.wait_for_eso_managed_sync,
  ]
}

data "kubernetes_secret" "paragon_secrets" {
  metadata {
    name      = "paragon-secrets"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [terraform_data.eso_secrets_gate]
}

data "kubernetes_secret" "docker_cfg" {
  metadata {
    name      = "docker-cfg"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [terraform_data.eso_secrets_gate]
}

data "kubernetes_secret" "openobserve_credentials" {
  count = var.openobserve_secret_name != null ? 1 : 0

  metadata {
    name      = "openobserve-credentials"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [terraform_data.eso_secrets_gate]
}

data "kubernetes_secret" "managed_sync_secrets" {
  count = var.managed_sync_secret_name != null ? 1 : 0

  metadata {
    name      = "paragon-managed-sync-secrets"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [terraform_data.eso_secrets_gate]
}
