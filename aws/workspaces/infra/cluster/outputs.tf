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

output "cluster_autoscaler_enabled" {
  description = "Whether legacy managed node groups require cluster-autoscaler."
  value       = local.cluster_autoscaler_enabled
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the cluster-autoscaler service account (non-GitOps path only)."
  value       = length(module.cluster_autoscaler) > 0 ? module.cluster_autoscaler[0].iam_role_attributes.arn : null
}

output "enable_karpenter" {
  description = "Whether Karpenter autoscaling is enabled. Consumed by paragon workspace for EC2NodeClass and NodePool manifests."
  value       = var.enable_karpenter
}

output "k8s_version" {
  description = "EKS control plane version. Consumed by paragon workspace for Karpenter drift tagging."
  value       = var.k8s_version
}

output "enable_legacy_mng_pools" {
  description = "Whether legacy on-demand and spot managed node groups are active. Consumed by paragon workspace for conditional AWS Node Termination Handler (NTH) deployment on legacy managed node groups."
  value       = var.enable_karpenter ? var.enable_legacy_mng_pools : true
}

output "karpenter" {
  description = "AWS resources created by infra for Karpenter worker nodes. Consumed by paragon workspace."
  value = var.enable_karpenter ? {
    node_role_name     = module.iam[0].node_iam_role_name
    security_group_ids = local.eks_worker_security_group_ids
    ebs_kms_key_arn    = module.ebs_kms_key.key_arn
  } : null
}
