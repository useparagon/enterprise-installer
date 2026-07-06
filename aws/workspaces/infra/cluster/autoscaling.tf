resource "aws_iam_service_linked_role" "autoscaling" {
  count            = var.create_autoscaling_linked_role ? 1 : 0
  aws_service_name = "autoscaling.amazonaws.com"
}

locals {
  autoscaling_role_arn = var.create_autoscaling_linked_role ? aws_iam_service_linked_role.autoscaling[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"

  cluster_autoscaler_label_tags = merge([
    for name, group in module.eks_managed_node_group : {
      for label_name, label_value in coalesce(try(local.managed_node_groups[name].labels, {}), {}) : "${name}|label|${label_name}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0]
        key               = "k8s.io/cluster-autoscaler/node-template/label/${label_name}"
        value             = label_value
      }
    } if contains(keys(local.cluster_autoscaler_node_groups), name)
  ]...)

  cluster_autoscaler_taint_tags = merge([
    for name, group in module.eks_managed_node_group : {
      for taint in coalesce(try(local.managed_node_groups[name].taints, []), []) : "${name}|taint|${taint.key}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0]
        key               = "k8s.io/cluster-autoscaler/node-template/taint/${taint.key}"
        value             = "${try(taint.value, "")}:${local.taint_effects[taint.effect]}"
      }
    } if contains(keys(local.cluster_autoscaler_node_groups), name)
  ]...)

  cluster_autoscaler_asg_tags = merge(local.cluster_autoscaler_label_tags, local.cluster_autoscaler_taint_tags)
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_label_tags" {
  for_each = local.cluster_autoscaler_enabled ? local.cluster_autoscaler_asg_tags : {}

  autoscaling_group_name = each.value.autoscaling_group

  tag {
    key   = each.value.key
    value = each.value.value

    propagate_at_launch = false
  }
}

# Module gained count for conditional enablement; preserve existing cluster-autoscaler state.
moved {
  from = module.cluster_autoscaler
  to   = module.cluster_autoscaler[0]
}

module "cluster_autoscaler" {
  count = local.cluster_autoscaler_enabled ? 1 : 0

  source  = "lablabs/eks-cluster-autoscaler/aws"
  version = "2.2.0"

  cluster_name                     = module.eks.cluster_name
  cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
  irsa_role_name_prefix            = "${var.workspace}-irsa"

  # Slightly conservative scale-down to reduce churn on critical system pods.
  # Ingress controller pods are also protected via safe-to-evict: "false".
  values = yamlencode({
    extraArgs = {
      scale-down-utilization-threshold = "0.65"
      scale-down-unneeded-time         = "15m"
      skip-nodes-with-system-pods      = true
    }
  })

  depends_on = [
    module.eks,
    module.eks_managed_node_group
  ]
}
