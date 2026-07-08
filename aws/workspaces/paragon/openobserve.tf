data "aws_secretsmanager_secret_version" "infra_openobserve" {
  secret_id = data.aws_secretsmanager_secret.openobserve.id
}

locals {
  infra_openobserve_credentials = jsondecode(data.aws_secretsmanager_secret_version.infra_openobserve.secret_string)

  openobserve_email = coalesce(
    var.openobserve_email,
    local.infra_openobserve_credentials.ZO_ROOT_USER_EMAIL
  )
  openobserve_password = coalesce(
    var.openobserve_password,
    local.infra_openobserve_credentials.ZO_ROOT_USER_PASSWORD
  )
}
