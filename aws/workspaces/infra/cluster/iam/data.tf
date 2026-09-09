data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_service_principal" "ec2" {
  service_name = "ec2"
}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  partition   = data.aws_partition.current.partition
  ec2_sp_name = data.aws_service_principal.ec2.name

  node_policy_prefix = "arn:${local.partition}:iam::aws:policy"

  ssm_parameter_resources = length(var.ami_id_ssm_parameter_arns) > 0 ? var.ami_id_ssm_parameter_arns : [
    "arn:${local.partition}:ssm:${var.aws_region}::parameter/aws/service/*"
  ]

  ipv4_cni_policy = var.attach_cni_policy_to_node && var.cluster_ip_family == "ipv4" ? {
    AmazonEKS_CNI_Policy = "${local.node_policy_prefix}/AmazonEKS_CNI_Policy"
  } : {}

  ipv6_cni_policy = var.attach_cni_policy_to_node && var.cluster_ip_family == "ipv6" ? {
    AmazonEKS_CNI_IPv6_Policy = "arn:${local.partition}:iam::${local.account_id}:policy/AmazonEKS_CNI_IPv6_Policy"
  } : {}
}
