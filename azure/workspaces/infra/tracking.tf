output "tracking" {
  description = "Non-sensitive deployment metadata for external environment tracking."
  value = {
    workspace    = local.workspace
    cloud        = "azure"
    organization = var.organization
    k8s_version  = var.k8s_version
  }
}
