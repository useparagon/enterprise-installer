variable "runtime_secrets_ready" {
  description = "Parent module signal that Secrets Manager secret versions are populated."
  type        = string
}

resource "terraform_data" "runtime_secrets_ready" {
  input = var.runtime_secrets_ready
}
