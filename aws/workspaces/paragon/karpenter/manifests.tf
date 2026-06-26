locals {
  ec2 = local.karpenter.ec2_node_class

  karpenter_ec2_node_class_spec_base = {
    role = local.ec2.role
    amiSelectorTerms = [
      { alias = local.ec2.ami_selector_alias }
    ]
    subnetSelectorTerms = [
      {
        tags = {
          "karpenter.sh/discovery" = local.karpenter.discovery_tag_value
        }
      }
    ]
    securityGroupSelectorTerms = [
      for sg_id in local.ec2.security_group_ids : {
        id = sg_id
      }
    ]
    blockDeviceMappings = [
      {
        deviceName = "/dev/xvda"
        ebs = {
          volumeSize          = "${var.ebs_volume_size_gib}Gi"
          volumeType          = "gp3"
          iops                = 3000
          throughput          = 125
          encrypted           = true
          kmsKeyID            = local.ec2.ebs_kms_key_arn
          deleteOnTermination = true
        }
      }
    ]
    metadataOptions = {
      httpEndpoint            = local.ec2.metadata_options.http_endpoint
      httpTokens              = local.ec2.metadata_options.http_tokens
      httpPutResponseHopLimit = local.ec2.metadata_options.http_put_response_hop_limit
    }
  }

  karpenter_ec2_node_class_specs = {
    for class_name, cfg in local.ec2.node_classes : class_name => merge(
      local.karpenter_ec2_node_class_spec_base,
      {
        tags = {
          Name                                   = cfg.ec2_name_tag
          "useparagon.io/eks-kubernetes-version" = local.karpenter.kubernetes_version
        }
      },
      try(local.ec2.kubelet_max_pods, null) != null ? { kubelet = { maxPods = local.ec2.kubelet_max_pods } } : {},
    )
  }

  karpenter_requirements_for_pool = {
    for pool_name, pool in local.karpenter.node_pools : pool_name => [
      {
        key      = "karpenter.k8s.aws/instance-category"
        operator = "In"
        values   = pool.requirements.instance_categories
      },
      {
        key      = "node.kubernetes.io/instance-type"
        operator = "In"
        values   = pool.requirements.instance_types
      },
      {
        key      = "karpenter.k8s.aws/instance-hypervisor"
        operator = "In"
        values   = pool.requirements.instance_hypervisor_values
      },
      {
        key      = "kubernetes.io/arch"
        operator = "In"
        values   = pool.requirements.architectures
      },
      {
        key      = "topology.kubernetes.io/zone"
        operator = "In"
        values   = local.karpenter.availability_zones
      },
    ]
  }

  karpenter_disruption_for_pool = {
    for pool_name, pool in local.karpenter.node_pools : pool_name => merge(
      {
        consolidateAfter    = pool.disruption.consolidate_after
        consolidationPolicy = pool.disruption.consolidation_policy
      },
      length(pool.disruption.budgets) > 0 ? {
        budgets = [
          for b in pool.disruption.budgets : merge(
            { nodes = b.nodes },
            try(b.reasons, null) != null ? { reasons = b.reasons } : {},
            try(b.schedule, null) != null && try(b.duration, null) != null ? { schedule = b.schedule, duration = b.duration } : {}
          )
        ]
      } : {}
    )
  }

  karpenter_node_pool_specs = {
    for name, pool in local.karpenter.node_pools : name => merge(
      {
        limits = {
          cpu    = pool.limits.cpu
          memory = pool.limits.memory
          nodes  = pool.limits.nodes
        }
        disruption = local.karpenter_disruption_for_pool[name]
        template = {
          metadata = {
            labels = merge(
              {
                "useparagon.com/capacityType" = pool.capacity_type_label
              },
              coalesce(try(pool.labels, {}), {}),
            )
          }
          spec = merge(
            {
              expireAfter            = pool.expire_after
              terminationGracePeriod = pool.termination_grace_period
              nodeClassRef = {
                group = "karpenter.k8s.aws"
                kind  = "EC2NodeClass"
                name  = pool.ec2_node_class
              }
              requirements = concat(
                local.karpenter_requirements_for_pool[name],
                [{
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = pool.capacity_types
                }],
              )
            },
            length(coalesce(try(pool.taints, []), [])) > 0 ? {
              taints = [
                for taint in pool.taints : {
                  key    = taint.key
                  value  = try(taint.value, null)
                  effect = taint.effect
                }
              ]
            } : {},
          )
        }
      },
      try(pool.weight, null) != null ? { weight = pool.weight } : {},
    )
  }
}

resource "kubernetes_manifest" "ec2_node_class" {
  for_each = local.ec2.node_classes

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = each.key
    }
    spec = local.karpenter_ec2_node_class_specs[each.key]
  }

  field_manager {
    force_conflicts = true
  }
}

resource "kubernetes_manifest" "node_pool" {
  for_each = local.karpenter.node_pools

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = each.key
    }
    spec = local.karpenter_node_pool_specs[each.key]
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}
