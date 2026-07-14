resource "random_string" "openobserve_email" {
  count = var.openobserve_email == null ? 1 : 0

  length  = 10
  lower   = true
  upper   = false
  numeric = false
  special = false
}

resource "random_password" "openobserve_password" {
  count = var.openobserve_password == null ? 1 : 0

  length           = 32
  lower            = true
  numeric          = true
  special          = true
  upper            = true
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  openobserve_email    = var.openobserve_email != null ? var.openobserve_email : "${random_string.openobserve_email[0].result}@useparagon.com"
  openobserve_password = var.openobserve_password != null ? var.openobserve_password : random_password.openobserve_password[0].result
}
