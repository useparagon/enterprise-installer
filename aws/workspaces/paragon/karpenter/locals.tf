locals {
  karpenter_ec2_node_class_name = "default"

  karpenter_defaults_effective = merge(
    {
      ami_selector_alias              = "bottlerocket@latest"
      architectures                   = ["amd64"]
      instance_hypervisor_values      = ["nitro"]
      disruption_consolidation_policy = "WhenEmptyOrUnderutilized"
      disruption_consolidate_after    = "5m"
      disruption_budgets = [
        { nodes = "25%", reasons = ["Empty", "Drifted"] },
        { nodes = "20%", reasons = ["Underutilized"] },
      ]
      expire_after             = "168h"
      termination_grace_period = "1h"
    },
    {
      for k, v in var.karpenter_defaults : k => v if v != null
    },
  )

  karpenter_node_pools = {
    for name, pool in var.karpenter_node_pools : name => {
      capacity_type_label = replace(name, "default-", "")
      capacity_types      = pool.capacity_types
      weight              = pool.weight
      ec2_node_class      = local.karpenter_ec2_node_class_name
      limits = {
        cpu    = pool.cpu_limit
        memory = pool.memory_limit
        nodes  = pool.nodes_limit
      }
      requirements = {
        instance_types             = pool.instance_types
        instance_categories        = distinct([for instance_type in pool.instance_types : substr(instance_type, 0, 1)])
        architectures              = local.karpenter_defaults_effective.architectures
        instance_hypervisor_values = local.karpenter_defaults_effective.instance_hypervisor_values
      }
      disruption = {
        consolidation_policy = local.karpenter_defaults_effective.disruption_consolidation_policy
        consolidate_after    = local.karpenter_defaults_effective.disruption_consolidate_after
        budgets              = local.karpenter_defaults_effective.disruption_budgets
      }
      expire_after             = local.karpenter_defaults_effective.expire_after
      termination_grace_period = local.karpenter_defaults_effective.termination_grace_period
      labels                   = coalesce(try(pool.labels, null), {})
      taints                   = coalesce(try(pool.taints, null), [])
    }
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  karpenter = {
    kubernetes_version  = var.k8s_version
    discovery_tag_value = var.workspace
    availability_zones  = data.aws_availability_zones.available.names
    ec2_node_class = {
      role               = var.aws.node_role_name
      security_group_ids = var.aws.security_group_ids
      ami_selector_alias = local.karpenter_defaults_effective.ami_selector_alias
      ebs_kms_key_arn    = var.aws.ebs_kms_key_arn
      kubelet_max_pods   = try(local.karpenter_defaults_effective.ec2_kubelet_max_pods, null)
      metadata_options   = local.metadata_options
      node_classes = {
        (local.karpenter_ec2_node_class_name) = {
          ec2_name_tag = substr(var.workspace, 0, 38)
        }
      }
    }
    node_pools = local.karpenter_node_pools
  }
}
