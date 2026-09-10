resource "aws_eks_pod_identity_association" "s3" {
  for_each = var.service_accounts

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = each.value
  role_arn        = var.s3_role_arn
}

resource "aws_eks_pod_identity_association" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.agent_os_namespace
  service_account = var.agent_os_service_account
  role_arn        = var.agent_os_role_arn
}
