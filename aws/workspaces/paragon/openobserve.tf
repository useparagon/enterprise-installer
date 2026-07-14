# OpenObserve admin credentials are owned by the infra workspace
# (aws/workspaces/infra/secrets → paragon/<workspace>/openobserve) and synced
# into the cluster by ESO as openobserve-credentials. These locals are for
# Terraform outputs / operators only — Helm does not inject them.

locals {
  infra_openobserve_credentials = jsondecode(data.aws_secretsmanager_secret_version.openobserve.secret_string)

  openobserve_email    = local.infra_openobserve_credentials.ZO_ROOT_USER_EMAIL
  openobserve_password = local.infra_openobserve_credentials.ZO_ROOT_USER_PASSWORD
}
