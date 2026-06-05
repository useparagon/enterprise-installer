output "eks_cluster" {
  value = {
    name                               = var.workspace
    arn                                = module.eks.cluster_arn
    id                                 = module.eks.cluster_id
    sg_id                              = module.eks.cluster_primary_security_group_id
    oidc_provider_arn                  = module.eks.oidc_provider_arn
    cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
    cluster_endpoint                   = module.eks.cluster_endpoint
    cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  }
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the cluster-autoscaler service account (non-GitOps path only)."
  value       = length(module.cluster_autoscaler) > 0 ? module.cluster_autoscaler[0].iam_role_attributes.arn : null
}
