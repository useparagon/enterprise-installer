output "tracking" {
  description = "Non-sensitive deployment metadata for external environment tracking."
  value = {
    workspace            = local.workspace
    cloud                = "gcp"
    organization         = var.organization
    app_version          = nonsensitive(tostring(coalesce(local.effective_platform_version, "")))
    installer_version    = local.installer_chart_version
    k8s_version          = try(local.infra_vars.k8s_version.value, var.k8s_version)
    managed_sync_enabled = var.managed_sync_enabled
    managed_sync_version = var.managed_sync_version
    domain               = var.domain
    dashboard_url        = try(local.microservices.dashboard.public_url, "https://dashboard.${var.domain}")
    grafana_url          = try(local.monitors["grafana"].public_url, "https://grafana.${var.domain}")
  }
}
