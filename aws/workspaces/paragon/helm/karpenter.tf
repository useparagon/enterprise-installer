locals {
  karpenter_helm_values = yamlencode({
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = var.karpenter_controller_role_arn
      }
    }
    settings = merge(
      { clusterName = var.cluster_name },
      var.karpenter_interruption_queue_name != null && var.karpenter_interruption_queue_name != "" ? {
        interruptionQueue = var.karpenter_interruption_queue_name
      } : {}
    )
    replicas = 2
  })
}

resource "kubernetes_namespace" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  metadata {
    name = "karpenter"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name             = "karpenter"
  description      = "Karpenter node provisioning controller"
  chart            = "karpenter"
  version          = var.karpenter_chart_version
  repository       = "oci://public.ecr.aws/karpenter"
  namespace        = kubernetes_namespace.karpenter[0].metadata[0].name
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  force_update     = true
  timeout          = 600

  values = [local.karpenter_helm_values]

  depends_on = [
    helm_release.ingress,
    kubernetes_namespace.karpenter
  ]
}

resource "kubernetes_manifest" "karpenter_ec2_node_class" {
  count = var.enable_karpenter ? 1 : 0

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      role = var.karpenter_node_iam_role_name
      amiSelectorTerms = [
        {
          alias = "al2023@latest"
        }
      ]
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "karpenter_node_pool_default" {
  count = var.enable_karpenter ? 1 : 0

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      limits = {
        cpu = "1000"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "5m"
        budgets = [
          {
            nodes = "10%"
          }
        ]
      }
      template = {
        spec = {
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.karpenter_ec2_node_class]
}
