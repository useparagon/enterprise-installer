resource "kubernetes_namespace" "paragon" {
  count = var.argocd_enabled ? 0 : 1

  metadata {
    name = "paragon"

    annotations = {
      name = "paragon"
    }

    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

data "kubernetes_namespace" "paragon" {
  count = var.argocd_enabled ? 1 : 0

  metadata {
    name = "paragon"
  }
}

resource "kubernetes_labels" "paragon_namespace" {
  count = var.argocd_enabled ? 1 : 0

  api_version = "v1"
  kind        = "Namespace"

  metadata {
    name = "paragon"
  }

  labels = {
    "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
  }

  depends_on = [data.kubernetes_namespace.paragon]
}

locals {
  paragon_namespace = var.argocd_enabled ? data.kubernetes_namespace.paragon[0].metadata[0].name : kubernetes_namespace.paragon[0].metadata[0].name
}
