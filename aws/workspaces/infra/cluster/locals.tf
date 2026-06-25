data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ec2_instance_type" "node" {
  for_each = local.node_instance_types_all

  instance_type = each.key
}

locals {
  node_volume_size = 50

  system_node_group_map_key = coalesce(var.eks_system_managed_node_group.map_key, "node-default")
  system_node_group_name = coalesce(
    var.eks_system_managed_node_group.name,
    "${var.workspace}-${local.system_node_group_map_key}",
  )

  node_instance_types_all = toset(distinct(concat(
    var.eks_ondemand_node_instance_type,
    var.eks_spot_node_instance_type,
    var.eks_system_managed_node_group.instance_types,
  )))

  legacy_node_groups = {
    for key, value in {
      ondemand = var.eks_spot_instance_percent == 100 ? null : {
        min_count      = ceil(var.eks_min_node_count * (1 - (var.eks_spot_instance_percent / 100)))
        max_count      = ceil(var.eks_max_node_count * (1 - (var.eks_spot_instance_percent / 100)))
        instance_types = var.eks_ondemand_node_instance_type
        capacity       = "ON_DEMAND"
        ami_type       = var.enable_karpenter ? "BOTTLEROCKET_x86_64" : null
        labels = {
          "useparagon.com/capacityType" = "ondemand"
        }
      }
      spot = var.eks_spot_instance_percent == 0 ? null : {
        min_count      = floor(var.eks_min_node_count * (var.eks_spot_instance_percent / 100))
        max_count      = ceil(var.eks_max_node_count * (var.eks_spot_instance_percent / 100))
        instance_types = var.eks_spot_node_instance_type
        capacity       = "SPOT"
        ami_type       = var.enable_karpenter ? "BOTTLEROCKET_x86_64" : null
        labels = {
          "useparagon.com/capacityType" = "spot"
        }
      }
    } : key => value
    if value != null
  }

  system_node_group = {
    min_count      = var.eks_system_managed_node_group.min_size
    max_count      = var.eks_system_managed_node_group.max_size
    desired_size   = var.eks_system_managed_node_group.desired_size
    instance_types = var.eks_system_managed_node_group.instance_types
    capacity       = "ON_DEMAND"
    ami_type        = "BOTTLEROCKET_x86_64"
    labels          = var.eks_system_managed_node_group.labels
    use_name_prefix = coalesce(var.eks_system_managed_node_group.use_name_prefix, false)
  }

  managed_node_groups = var.enable_karpenter ? merge(
    { system = local.system_node_group },
    var.enable_legacy_mng_pools ? local.legacy_node_groups : {},
  ) : local.legacy_node_groups

  cluster_autoscaler_node_groups = var.enable_karpenter ? merge(
    { system = local.system_node_group },
    var.enable_legacy_mng_pools ? local.legacy_node_groups : {},
  ) : local.legacy_node_groups

  cluster_autoscaler_enabled = length(local.cluster_autoscaler_node_groups) > 0

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

  spot_pool_cpu_limit = local.spot_largest_instance != null ? tostring(local.spot_nodes_max * data.aws_ec2_instance_type.node[local.spot_largest_instance].default_vcpus) : "0"
  spot_pool_memory_limit = local.spot_largest_instance != null ? "${local.spot_nodes_max * data.aws_ec2_instance_type.node[local.spot_largest_instance].memory_size / 1024}Gi" : "0Gi"

  ondemand_pool_cpu_limit = local.ondemand_largest_instance != null ? tostring(local.ondemand_nodes_max * data.aws_ec2_instance_type.node[local.ondemand_largest_instance].default_vcpus) : "0"
  ondemand_pool_memory_limit = local.ondemand_largest_instance != null ? "${local.ondemand_nodes_max * data.aws_ec2_instance_type.node[local.ondemand_largest_instance].memory_size / 1024}Gi" : "0Gi"

  karpenter_spot_weight     = var.eks_spot_instance_percent
  karpenter_ondemand_weight = 100 - var.eks_spot_instance_percent

  karpenter_defaults_effective = merge(
    {
      ec2_node_class_name             = "default"
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
    cpu_limit       = local.spot_pool_cpu_limit
    memory_limit    = local.spot_pool_memory_limit
    nodes_limit     = local.spot_nodes_max
    instance_types  = var.eks_spot_node_instance_type
    instance_categories = distinct([for instance_type in var.eks_spot_node_instance_type : substr(instance_type, 0, 1)])
  }

  karpenter_ondemand_defaults = {
    cpu_limit       = local.ondemand_pool_cpu_limit
    memory_limit    = local.ondemand_pool_memory_limit
    nodes_limit     = local.ondemand_nodes_max
    instance_types  = var.eks_ondemand_node_instance_type
    instance_categories = distinct([for instance_type in var.eks_ondemand_node_instance_type : substr(instance_type, 0, 1)])
  }

  karpenter_builtin_ec2_node_class_names = {
    "default-spot"     = "spot"
    "default-ondemand" = "ondemand"
  }

  # Maps builtin Karpenter NodePools to legacy MNG pool keys (same random suffix / Name tag).
  karpenter_pool_legacy_mng_keys = {
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

  # Worker EC2 Name tags match legacy MNG node group prefix: <workspace>-<random6> (e.g. paragon-admin-a1b2c3d4-kxmfab).
  worker_node_ec2_name_tags = {
    for key in keys(local.legacy_node_groups) : key => substr(
      "${var.workspace}-${random_string.node_group[key].result}",
      0,
      38,
    )
  }

  karpenter_pool_effective_with_names = {
    for pool_name, pool_cfg in local.karpenter_pool_effective : pool_name => merge(
      pool_cfg,
      {
        ec2_name_tag = coalesce(
          try(var.karpenter_node_pool_overrides[pool_name].ec2_name_tag, null),
          try(local.worker_node_ec2_name_tags[local.karpenter_pool_legacy_mng_keys[pool_name]], null),
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

  cluster_addons_legacy = {
    aws-ebs-csi-driver = {
      version = "v1.55.0-eksbuild.2"
    }
    coredns = {
      version = "v1.13.2-eksbuild.1"
    }
    kube-proxy = {
      version = "v1.33.7-eksbuild.2"
    }
    vpc-cni = {
      version = "v1.21.1-eksbuild.3"
    }
  }

  cluster_addons = local.cluster_addons_legacy

  cluster_addons_karpenter = {
    vpc-cni = {
      version = "v1.21.1-eksbuild.3"
    }
    eks-pod-identity-agent = {
      version = "v1.3.10-eksbuild.3"
    }
    kube-proxy = {
      version = "v1.33.7-eksbuild.2"
    }
    coredns = {
      version = "v1.13.2-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      version = "v1.55.0-eksbuild.2"
    }
  }

  eks_addon_versions = {
    for name, cfg in local.cluster_addons_karpenter : name => cfg.version
  }

  eks_addon_resolve_conflicts = {
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
  }

  karpenter_controller_role_name = coalesce(var.karpenter_iam_names.controller_role_name, "${var.workspace}-karpenter-controller")
  karpenter_node_role_name       = coalesce(var.karpenter_iam_names.node_role_name, "${var.workspace}-karpenter-node")

  eks_worker_security_group_ids = compact([
    module.eks.node_security_group_id,
  ])

  karpenter_node_iam_additional_policies = {
    custom_worker = aws_iam_policy.eks_worker_policy.arn
    ssm           = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  is_assumed_role = can(regex("assumed-role", data.aws_caller_identity.current.arn))
  assumed_role_parts = split(
    "/",
    replace(
      replace(
        data.aws_caller_identity.current.arn,
        ":sts:",
        ":iam:"
      ),
      ":assumed-role/",
      local.is_assumed_role && strcontains(data.aws_caller_identity.current.arn, ":assumed-role/AWSReservedSSO") ? ":role__TEMPORARY_DIVIDER__aws-reserved__TEMPORARY_DIVIDER__sso.amazonaws.com/" : ":role/"
    )
  )
  caller_arn = local.is_assumed_role ? replace(format("%s/%s", local.assumed_role_parts[0], local.assumed_role_parts[1]), "__TEMPORARY_DIVIDER__", "/") : data.aws_caller_identity.current.arn

  eks_admin_arns = distinct(compact(concat(
    var.eks_admin_arns,
    [local.caller_arn]
  )))

  taint_effects = {
    NO_SCHEDULE        = "NoSchedule"
    NO_EXECUTE         = "NoExecute"
    PREFER_NO_SCHEDULE = "PreferNoSchedule"
  }
}
