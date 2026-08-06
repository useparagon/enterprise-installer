provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
  region     = var.aws_region

  dynamic "assume_role" {
    for_each = var.aws_assume_role_arn != null && var.aws_assume_role_arn != "" ? [1] : []
    content {
      role_arn = var.aws_assume_role_arn
    }
  }

  default_tags {
    tags = local.default_tags
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
