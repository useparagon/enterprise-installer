# Grafana / pgAdmin admin credentials for the flat env secret (ESO).
# Always generated so values stay stable in state when monitors are toggled.
# Override via var.argocd_app_secrets (MONITOR_PGADMIN_* / MONITOR_GRAFANA_SECURITY_*)
# to reuse brownfield credentials from a legacy paragon workspace.

resource "random_string" "grafana_admin_email_prefix" {
  length  = 16
  special = false
  numeric = false
  lower   = true
  upper   = false
}

resource "random_password" "grafana_admin_password" {
  length      = 16
  min_upper   = 2
  min_lower   = 2
  min_special = 0
  numeric     = true
  special     = false
  lower       = true
  upper       = true
}

resource "random_string" "pgadmin_admin_email_prefix" {
  length  = 16
  special = false
  numeric = false
  lower   = true
  upper   = false
}

resource "random_password" "pgadmin_admin_password" {
  length      = 16
  min_upper   = 2
  min_lower   = 2
  min_special = 0
  numeric     = true
  special     = false
  lower       = true
  upper       = true
}

locals {
  argocd_monitor_creds = {
    MONITOR_GRAFANA_SECURITY_ADMIN_USER     = "${random_string.grafana_admin_email_prefix.result}@useparagon.com"
    MONITOR_GRAFANA_SECURITY_ADMIN_PASSWORD = random_password.grafana_admin_password.result
    MONITOR_PGADMIN_EMAIL                   = "${random_string.pgadmin_admin_email_prefix.result}@useparagon.com"
    MONITOR_PGADMIN_PASSWORD                = random_password.pgadmin_admin_password.result
  }
}
