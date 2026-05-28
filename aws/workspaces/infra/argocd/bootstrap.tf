locals {
  eso_namespace = "external-secrets"
  eso_sa_name   = "external-secrets"

  # Manifests only reference Secrets Manager keys, not secret values; nonsensitive()
  # is required because the argocd_apps module output inherits sensitivity from
  # other module inputs (for_each cannot use sensitive values).
  application_docs = [
    for m in nonsensitive(var.argocd_application_manifests) : nonsensitive(yamldecode(m))
  ]

  external_secret_manifests = nonsensitive({
    for idx, doc in local.application_docs : "es-${idx}" => doc
    if try(doc.kind, "") == "ExternalSecret"
  })

  argocd_application_manifests = nonsensitive({
    for idx, doc in local.application_docs : "app-${idx}" => doc
    if try(doc.kind, "") == "Application"
  })

  gitops_bridge_annotations = merge(
    {
      "aws_region"                  = var.aws_region
      "aws_cluster_name"            = var.cluster_name
      "cluster_name"                = "in-cluster"
      "environment"                 = var.workspace
      "cluster_autoscaler_role_arn" = aws_iam_role.cluster_autoscaler.arn
    },
    length(var.secrets_manager_secret_arns) > 0 ? {
      "secrets_manager_prefix" = "paragon/${var.workspace}"
    } : {}
  )
}

# Namespaces and gp3 StorageClass are not managed here: legacy SSM bootstrap (and
# Helm create_namespace) already created them on brownfield clusters, and
# kubernetes_manifest cannot adopt without a prior import. The paragon namespace
# is labeled by Argo CD Applications (CreateNamespace=true).

resource "kubernetes_storage_class_v1" "gp3" {
  count = var.create_gp3_storage_class ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    encrypted = "true"
    fsType    = "ext4"
    type      = "gp3"
  }
}

resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_helm_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  timeout          = 600
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode({
      global = {
        image = {
          tag = var.argocd_version
        }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = local.eso_namespace
  create_namespace = true
  timeout          = 600
  wait             = true
  wait_for_jobs    = true

  set {
    name  = "serviceAccount.name"
    value = local.eso_sa_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
  }

  depends_on = [
    helm_release.argocd,
    aws_iam_role_policy.eso_secrets,
  ]
}

# GitOps bridge metadata (EKS Blueprints pattern): annotate the in-cluster
# Argo CD cluster secret so ApplicationSets can read cloud/IAM context.
# https://aws-ia.github.io/terraform-aws-eks-blueprints/patterns/gitops/gitops-getting-started-argocd/
resource "kubernetes_annotations" "gitops_bridge" {
  api_version = "v1"
  kind        = "Secret"

  metadata {
    name      = "${helm_release.argocd.name}-cluster"
    namespace = var.argocd_namespace
  }

  annotations = local.gitops_bridge_annotations

  depends_on = [helm_release.argocd]
}

resource "kubernetes_labels" "gitops_bridge" {
  api_version = "v1"
  kind        = "Secret"

  metadata {
    name      = "${helm_release.argocd.name}-cluster"
    namespace = var.argocd_namespace
  }

  labels = {
    "aws_cluster_name" = var.cluster_name
    "cluster_name"     = "in-cluster"
    "environment"      = var.workspace
    "enable_argocd"    = "true"
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = local.eso_sa_name
                namespace = local.eso_namespace
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_manifest" "argocd_applications" {
  for_each = local.argocd_application_manifests

  manifest = each.value

  depends_on = [
    helm_release.argocd,
    kubernetes_manifest.cluster_secret_store,
  ]
}

resource "kubernetes_manifest" "external_secrets" {
  for_each = local.external_secret_manifests

  manifest = each.value

  depends_on = [kubernetes_manifest.cluster_secret_store]
}
