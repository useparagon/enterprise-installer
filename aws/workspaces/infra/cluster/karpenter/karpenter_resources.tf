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
      tolerations = [
        {
          key      = "karpenter.sh/controller"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        },
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        },
      ]
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

# EC2NodeClass / NodePool CRs are applied from the paragon workspace (infra apply must run first).
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

removed {
  from = kubernetes_manifest.ec2_node_class

  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_manifest.node_pool

  lifecycle {
    destroy = false
  }
}
