locals {
  karpenter_ec2_node_class_spec_base = {
    role = var.node_iam_role_name
    amiSelectorTerms = [
      { alias = var.ami_selector_alias }
    ]
    subnetSelectorTerms = [
      {
        tags = {
          "karpenter.sh/discovery" = var.discovery_tag_value
        }
      }
    ]
    securityGroupSelectorTerms = [
      for sg_id in var.node_security_group_ids : {
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
          kmsKeyID            = var.ebs_kms_key_arn
          deleteOnTermination = true
        }
      }
    ]
    metadataOptions = {
      httpEndpoint            = var.metadata_options.http_endpoint
      httpTokens              = var.metadata_options.http_tokens
      httpPutResponseHopLimit = var.metadata_options.http_put_response_hop_limit
    }
  }

  karpenter_ec2_node_class_specs = {
    for class_name, cfg in var.ec2_node_classes : class_name => merge(
      local.karpenter_ec2_node_class_spec_base,
      {
        tags = {
          Name                                   = cfg.ec2_name_tag
          "useparagon.io/eks-kubernetes-version" = var.kubernetes_version
        }
      },
      var.ec2_kubelet_max_pods != null ? { kubelet = { maxPods = var.ec2_kubelet_max_pods } } : {},
    )
  }

  karpenter_requirements_for_pool = {
    for pool_name, pe in var.node_pool_effective : pool_name => [
      {
        key      = "karpenter.k8s.aws/instance-category"
        operator = "In"
        values   = pe.instance_categories
      },
      {
        key      = "node.kubernetes.io/instance-type"
        operator = "In"
        values   = pe.instance_types
      },
      {
        key      = "karpenter.k8s.aws/instance-hypervisor"
        operator = "In"
        values   = pe.instance_hypervisor_values
      },
      {
        key      = "kubernetes.io/arch"
        operator = "In"
        values   = pe.architectures
      },
      {
        key      = "topology.kubernetes.io/zone"
        operator = "In"
        values   = var.availability_zones
      },
    ]
  }

  karpenter_disruption_for_pool = {
    for pool_name, pe in var.node_pool_effective : pool_name => merge(
      {
        consolidateAfter    = pe.disruption_consolidate_after
        consolidationPolicy = pe.disruption_consolidation_policy
      },
      length(pe.disruption_budgets) > 0 ? {
        budgets = [
          for b in pe.disruption_budgets : merge(
            { nodes = b.nodes },
            try(b.reasons, null) != null ? { reasons = b.reasons } : {},
            try(b.schedule, null) != null && try(b.duration, null) != null ? { schedule = b.schedule, duration = b.duration } : {}
          )
        ]
      } : {}
    )
  }

  karpenter_node_pool_specs = {
    for name, cfg in var.node_pool_definitions : name => merge(
      {
        limits = {
          cpu    = var.node_pool_effective[name].cpu_limit
          memory = var.node_pool_effective[name].memory_limit
          nodes  = var.node_pool_effective[name].nodes_limit
        }
        disruption = local.karpenter_disruption_for_pool[name]
        template = {
          metadata = {
            labels = merge(
              {
                "useparagon.com/capacityType" = cfg.capacity_type_label
              },
              coalesce(try(cfg.labels, {}), {}),
            )
          }
          spec = merge(
            {
              expireAfter            = var.node_pool_effective[name].expire_after
              terminationGracePeriod = var.node_pool_effective[name].termination_grace_period
              nodeClassRef = {
                group = "karpenter.k8s.aws"
                kind  = "EC2NodeClass"
                name  = var.node_pool_effective[name].ec2_node_class_name
              }
              requirements = concat(
                local.karpenter_requirements_for_pool[name],
                [{
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = cfg.capacity_types
                }],
              )
            },
            length(coalesce(try(cfg.taints, []), [])) > 0 ? {
              taints = [
                for taint in cfg.taints : {
                  key    = taint.key
                  value  = try(taint.value, null)
                  effect = taint.effect
                }
              ]
            } : {},
          )
        }
      },
      try(cfg.weight, null) != null ? { weight = cfg.weight } : {},
    )
  }
}

resource "helm_release" "karpenter" {
  count = var.create ? 1 : 0

  name      = "karpenter"
  namespace = "kube-system"
  version   = var.chart_version

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"

  wait          = true
  wait_for_jobs = true
  atomic        = true
  timeout       = 600

  values = [
    yamlencode({
      nodeSelector = {
        "karpenter.sh/controller" = "true"
      }
      dnsPolicy = "ClusterFirst"
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = var.interruption_queue_name
        eksControlPlane   = false
      }
    })
  ]
}

resource "kubernetes_manifest" "ec2_node_class" {
  for_each = var.create ? var.ec2_node_classes : {}

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

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "node_pool" {
  for_each = var.create ? var.node_pool_definitions : {}

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

# Adopt existing Karpenter CRs from kubectl_manifest without deleting them in the cluster.
removed {
  from = kubectl_manifest.ec2_node_class

  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.node_pool

  lifecycle {
    destroy = false
  }
}
