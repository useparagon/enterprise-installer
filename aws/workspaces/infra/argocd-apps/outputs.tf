output "all_manifests" {
  description = "Flat list of all YAML manifests (ArgoCD Applications + ExternalSecrets) applied by the argocd bootstrap module."
  value       = nonsensitive(concat(values(local.all_external_secrets), values(local.all_applications)))
}
