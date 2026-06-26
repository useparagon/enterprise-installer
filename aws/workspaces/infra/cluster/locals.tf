locals {
  node_volume_size = 50

  system_node_group_map_key = coalesce(var.eks_system_managed_node_group.map_key, "node-default")
  system_node_group_name = coalesce(
    var.eks_system_managed_node_group.name,
    "${var.workspace}-${local.system_node_group_map_key}",
  )

  system_node_instance_types = [
    "t3a.medium",
    "t3a.large",
    "t3a.xlarge",
    "t3.medium",
    "t3.large",
    "t3.xlarge",
  ]

  legacy_node_groups = {
    for key, value in {
      ondemand = var.eks_spot_instance_percent == 100 ? null : {
        min_count      = ceil(var.eks_min_node_count * (1 - (var.eks_spot_instance_percent / 100)))
        max_count      = ceil(var.eks_max_node_count * (1 - (var.eks_spot_instance_percent / 100)))
        instance_types = var.eks_ondemand_node_instance_type
        capacity       = "ON_DEMAND"
        labels = {
          "useparagon.com/capacityType" = "ondemand"
        }
      }
      spot = var.eks_spot_instance_percent == 0 ? null : {
        min_count      = floor(var.eks_min_node_count * (var.eks_spot_instance_percent / 100))
        max_count      = ceil(var.eks_max_node_count * (var.eks_spot_instance_percent / 100))
        instance_types = var.eks_spot_node_instance_type
        capacity       = "SPOT"
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
    instance_types = coalesce(
      try(var.eks_system_managed_node_group.instance_types, null),
      local.system_node_instance_types,
    )
    capacity       = "ON_DEMAND"
    ami_type        = "BOTTLEROCKET_x86_64"
    labels          = var.eks_system_managed_node_group.labels
    use_name_prefix = coalesce(var.eks_system_managed_node_group.use_name_prefix, false)
  }

  managed_node_groups = merge(
    var.enable_karpenter ? { system = local.system_node_group } : {},
    (!var.enable_karpenter || var.enable_legacy_mng_pools) ? local.legacy_node_groups : {},
  )

  cluster_autoscaler_node_groups = (!var.enable_karpenter || var.enable_legacy_mng_pools) ? local.legacy_node_groups : {}

  cluster_autoscaler_enabled = length(local.cluster_autoscaler_node_groups) > 0

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

  eks_addon_versions = merge(
    { for name, cfg in local.cluster_addons_legacy : name => cfg.version },
    {
      "eks-pod-identity-agent" = local.cluster_addons_karpenter["eks-pod-identity-agent"].version
    },
  )

  eks_addon_resolve_conflicts = {
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "PRESERVE"
  }

  karpenter_controller_role_name = coalesce(var.karpenter_iam_names.controller_role_name, "${var.workspace}-karpenter-controller")
  karpenter_node_role_name       = coalesce(var.karpenter_iam_names.node_role_name, "${var.workspace}-karpenter-node")

  # Must match eks_managed_node_group in cluster.tf (cluster primary + cluster SG).
  # Do not use node_security_group_id alone — that SG is not attached to MNG workers.
  eks_worker_security_group_ids = compact([
    module.eks.cluster_primary_security_group_id,
    module.eks.cluster_security_group_id,
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
