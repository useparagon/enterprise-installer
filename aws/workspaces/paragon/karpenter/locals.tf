locals {
  node_instance_types_all = toset(distinct(concat(
    var.eks_ondemand_node_instance_type,
    var.eks_spot_node_instance_type,
  )))

  spot_nodes_max     = ceil(var.eks_max_node_count * var.eks_spot_instance_percent / 100)
  ondemand_nodes_max = ceil(var.eks_max_node_count * (100 - var.eks_spot_instance_percent) / 100)

  spot_largest_instance = var.eks_spot_instance_percent > 0 && length(var.eks_spot_node_instance_type) > 0 ? [
    for instance_type in var.eks_spot_node_instance_type :
    instance_type
    if data.aws_ec2_instance_type.node[instance_type].default_vcpus == max([
      for t in var.eks_spot_node_instance_type : data.aws_ec2_instance_type.node[t].default_vcpus
    ]...)
  ][0] : null

  ondemand_largest_instance = var.eks_spot_instance_percent < 100 && length(var.eks_ondemand_node_instance_type) > 0 ? [
    for instance_type in var.eks_ondemand_node_instance_type :
    instance_type
    if data.aws_ec2_instance_type.node[instance_type].default_vcpus == max([
      for t in var.eks_ondemand_node_instance_type : data.aws_ec2_instance_type.node[t].default_vcpus
    ]...)
  ][0] : null

  spot_pool_cpu_limit    = local.spot_largest_instance != null ? tostring(local.spot_nodes_max * data.aws_ec2_instance_type.node[local.spot_largest_instance].default_vcpus) : "0"
  spot_pool_memory_limit = local.spot_largest_instance != null ? "${local.spot_nodes_max * data.aws_ec2_instance_type.node[local.spot_largest_instance].memory_size / 1024}Gi" : "0Gi"

  ondemand_pool_cpu_limit    = local.ondemand_largest_instance != null ? tostring(local.ondemand_nodes_max * data.aws_ec2_instance_type.node[local.ondemand_largest_instance].default_vcpus) : "0"
  ondemand_pool_memory_limit = local.ondemand_largest_instance != null ? "${local.ondemand_nodes_max * data.aws_ec2_instance_type.node[local.ondemand_largest_instance].memory_size / 1024}Gi" : "0Gi"

  karpenter_spot_weight     = var.eks_spot_instance_percent
  karpenter_ondemand_weight = 100 - var.eks_spot_instance_percent

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
      default_spot_weight      = local.karpenter_spot_weight
      default_ondemand_weight  = local.karpenter_ondemand_weight
    },
    {
      for k, v in var.karpenter_defaults : k => v if v != null
    },
  )

  karpenter_spot_defaults = {
    cpu_limit           = local.spot_pool_cpu_limit
    memory_limit        = local.spot_pool_memory_limit
    nodes_limit         = local.spot_nodes_max
    instance_types      = var.eks_spot_node_instance_type
    instance_categories = distinct([for instance_type in var.eks_spot_node_instance_type : substr(instance_type, 0, 1)])
  }

  karpenter_ondemand_defaults = {
    cpu_limit           = local.ondemand_pool_cpu_limit
    memory_limit        = local.ondemand_pool_memory_limit
    nodes_limit         = local.ondemand_nodes_max
    instance_types      = var.eks_ondemand_node_instance_type
    instance_categories = distinct([for instance_type in var.eks_ondemand_node_instance_type : substr(instance_type, 0, 1)])
  }

  karpenter_builtin_ec2_node_class_names = {
    "default-spot"     = "spot"
    "default-ondemand" = "ondemand"
  }

  karpenter_builtin_node_pool_definitions = merge(
    var.eks_spot_instance_percent > 0 ? {
      "default-spot" = {
        capacity_types      = ["spot"]
        weight              = local.karpenter_spot_weight
        capacity_type_label = "spot"
      }
    } : {},
    var.eks_spot_instance_percent < 100 ? {
      "default-ondemand" = {
        capacity_types      = ["on-demand"]
        weight              = local.karpenter_ondemand_weight
        capacity_type_label = "ondemand"
      }
    } : {},
  )

  karpenter_custom_node_pool_definitions = {
    for name, cfg in var.karpenter_node_pools : name => {
      capacity_types      = cfg.capacity_types
      weight              = try(cfg.weight, null)
      capacity_type_label = try(cfg.capacity_type_label, name)
      taints              = try(cfg.taints, [])
      labels              = try(cfg.labels, {})
    }
  }

  karpenter_node_pool_definitions = merge(
    local.karpenter_builtin_node_pool_definitions,
    local.karpenter_custom_node_pool_definitions,
  )

  karpenter_custom_pool_defaults = {
    for name, cfg in var.karpenter_node_pools : name => {
      instance_types = coalesce(cfg.instance_types, var.eks_ondemand_node_instance_type)
      instance_categories = distinct([
        for instance_type in coalesce(cfg.instance_types, var.eks_ondemand_node_instance_type) :
        substr(instance_type, 0, 1)
      ])
      cpu_limit    = try(cfg.cpu_limit, null)
      memory_limit = try(cfg.memory_limit, null)
      nodes_limit  = try(cfg.nodes_limit, null)
    }
  }

  karpenter_pool_base_defaults = merge(
    var.eks_spot_instance_percent > 0 ? { "default-spot" = local.karpenter_spot_defaults } : {},
    var.eks_spot_instance_percent < 100 ? { "default-ondemand" = local.karpenter_ondemand_defaults } : {},
    local.karpenter_custom_pool_defaults,
  )

  karpenter_pool_effective = {
    for pool_name, pool_cfg in local.karpenter_node_pool_definitions : pool_name => merge(
      {
        architectures                   = local.karpenter_defaults_effective.architectures
        instance_hypervisor_values      = local.karpenter_defaults_effective.instance_hypervisor_values
        disruption_consolidation_policy = local.karpenter_defaults_effective.disruption_consolidation_policy
        disruption_consolidate_after    = local.karpenter_defaults_effective.disruption_consolidate_after
        disruption_budgets              = local.karpenter_defaults_effective.disruption_budgets
        expire_after                    = local.karpenter_defaults_effective.expire_after
        termination_grace_period        = local.karpenter_defaults_effective.termination_grace_period
        capacity_types                  = pool_cfg.capacity_types
        capacity_type_label             = pool_cfg.capacity_type_label
        weight                          = try(pool_cfg.weight, null)
        taints                          = try(pool_cfg.taints, [])
        labels                          = try(pool_cfg.labels, {})
        ec2_node_class_name = coalesce(
          try(local.karpenter_builtin_ec2_node_class_names[pool_name], null),
          pool_cfg.capacity_type_label,
        )
      },
      {
        for k, v in try(local.karpenter_pool_base_defaults[pool_name], {}) :
        k => v if v != null
      },
      {
        for k, v in try(var.karpenter_node_pool_overrides[pool_name], {}) :
        k => v if v != null
      },
    )
  }

  karpenter_pool_effective_with_names = {
    for pool_name, pool_cfg in local.karpenter_pool_effective : pool_name => merge(
      pool_cfg,
      {
        ec2_name_tag = coalesce(
          try(var.karpenter_node_pool_overrides[pool_name].ec2_name_tag, null),
          substr("${var.workspace}-${pool_cfg.capacity_type_label}", 0, 38),
        )
      },
    )
  }

  karpenter_ec2_node_classes = {
    for class_name in distinct([for _, pe in local.karpenter_pool_effective_with_names : pe.ec2_node_class_name]) :
    class_name => {
      ec2_name_tag = [
        for _, pe in local.karpenter_pool_effective_with_names : pe.ec2_name_tag
        if pe.ec2_node_class_name == class_name
      ][0]
    }
  }

  karpenter_node_pools = {
    for name, pool in local.karpenter_pool_effective_with_names : name => {
      capacity_type_label = pool.capacity_type_label
      capacity_types      = pool.capacity_types
      weight              = pool.weight
      ec2_node_class      = pool.ec2_node_class_name
      ec2_name_tag        = pool.ec2_name_tag
      limits = {
        cpu    = pool.cpu_limit
        memory = pool.memory_limit
        nodes  = pool.nodes_limit
      }
      requirements = {
        instance_types             = pool.instance_types
        instance_categories        = pool.instance_categories
        architectures              = pool.architectures
        instance_hypervisor_values = pool.instance_hypervisor_values
      }
      disruption = {
        consolidation_policy = pool.disruption_consolidation_policy
        consolidate_after    = pool.disruption_consolidate_after
        budgets              = pool.disruption_budgets
      }
      expire_after             = pool.expire_after
      termination_grace_period = pool.termination_grace_period
      labels                   = pool.labels
      taints                   = pool.taints
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
      node_classes       = local.karpenter_ec2_node_classes
    }
    node_pools = local.karpenter_node_pools
  }
}
