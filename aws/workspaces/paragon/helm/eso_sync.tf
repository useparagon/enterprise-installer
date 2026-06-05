locals {
  eso_sync_triggers = join(",", compact([
    kubectl_manifest.external_secret_paragon.uid,
    kubectl_manifest.external_secret_docker.uid,
    var.openobserve_secret_name != null ? try(kubectl_manifest.external_secret_openobserve[0].uid, null) : null,
    var.managed_sync_secret_name != null ? try(kubectl_manifest.external_secret_managed_sync[0].uid, null) : null,
  ]))
}

# ExternalSecret manifests apply synchronously; ESO populates target Secrets asynchronously.
resource "time_sleep" "wait_for_eso_secrets" {
  create_duration = "90s"

  depends_on = [
    kubectl_manifest.external_secret_paragon,
    kubectl_manifest.external_secret_docker,
  ]

  triggers = {
    external_secrets = local.eso_sync_triggers
  }
}

data "kubernetes_secret" "paragon_secrets" {
  metadata {
    name      = "paragon-secrets"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [time_sleep.wait_for_eso_secrets]
}

data "kubernetes_secret" "docker_cfg" {
  metadata {
    name      = "docker-cfg"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [time_sleep.wait_for_eso_secrets]
}

data "kubernetes_secret" "openobserve_credentials" {
  count = var.openobserve_secret_name != null ? 1 : 0

  metadata {
    name      = "openobserve-credentials"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [time_sleep.wait_for_eso_secrets]
}

data "kubernetes_secret" "managed_sync_secrets" {
  count = var.managed_sync_secret_name != null ? 1 : 0

  metadata {
    name      = "paragon-managed-sync-secrets"
    namespace = kubernetes_namespace.paragon.metadata[0].name
  }

  depends_on = [time_sleep.wait_for_eso_secrets]
}
