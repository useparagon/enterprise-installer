resource "aws_eks_pod_identity_association" "s3" {
  for_each = var.service_accounts

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = each.value
  role_arn        = var.s3_role_arn
}
