output "tracking" {
  description = "Non-sensitive deployment metadata for external environment tracking."
  value = {
    workspace    = local.workspace
    cloud        = "aws"
    organization = var.organization
    k8s_version  = module.cluster.k8s_version
  }
}
