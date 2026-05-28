locals {
  eso_namespace = "external-secrets"
  eso_sa_name   = "external-secrets"

  sync_policy = {
    automated = var.auto_sync ? {
      selfHeal = var.self_heal
      prune    = true
    } : null
    syncOptions = ["CreateNamespace=true"]
    retry = var.auto_sync ? {
      limit = 3
      backoff = {
        duration    = "30s"
        factor      = 2
        maxDuration = "5m"
      }
    } : null
  }

  app_of_apps_manifest = var.app_of_apps_manifest != null && trimspace(var.app_of_apps_manifest) != "" ? var.app_of_apps_manifest : (
    trimspace(var.bootstrap_repo_url) != "" && trimspace(var.bootstrap_repo_path) != "" ? yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "${var.workspace}-bootstrap"
        namespace = var.argocd_namespace
        finalizers = [
          "resources-finalizer.argocd.argoproj.io",
        ]
      }
      spec = {
        project = "default"
        source = {
          repoURL        = var.bootstrap_repo_url
          targetRevision = var.bootstrap_repo_revision
          path           = var.bootstrap_repo_path
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.argocd_namespace
        }
        syncPolicy = local.sync_policy
      }
    }) : null
  )

  external_secret_docs = [
    for m in compact([
      var.env_secret_name != null ? yamlencode({
        apiVersion = "external-secrets.io/v1beta1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "paragon-secrets"
          namespace = var.destination_namespace
        }
        spec = {
          refreshInterval = "5m"
          secretStoreRef = {
            name = var.cluster_secret_store_name
            kind = "ClusterSecretStore"
          }
          target = {
            name           = "paragon-secrets"
            creationPolicy = "Owner"
          }
          dataFrom = [{
            extract = {
              key = var.env_secret_name
            }
          }]
        }
      }) : null,
      var.docker_cfg_secret_name != null ? yamlencode({
        apiVersion = "external-secrets.io/v1beta1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "docker-cfg"
          namespace = var.destination_namespace
        }
        spec = {
          refreshInterval = "1h"
          secretStoreRef = {
            name = var.cluster_secret_store_name
            kind = "ClusterSecretStore"
          }
          target = {
            name           = "docker-cfg"
            creationPolicy = "Owner"
            template = {
              type = "kubernetes.io/dockerconfigjson"
              data = {
                ".dockerconfigjson" = "{{ .dockerconfigjson }}"
              }
            }
          }
          data = [{
            secretKey = "dockerconfigjson"
            remoteRef = {
              key = var.docker_cfg_secret_name
            }
          }]
        }
      }) : null,
      var.managed_sync_secret_name != null ? yamlencode({
        apiVersion = "external-secrets.io/v1beta1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "paragon-managed-sync-secrets"
          namespace = var.destination_namespace
        }
        spec = {
          refreshInterval = "5m"
          secretStoreRef = {
            name = var.cluster_secret_store_name
            kind = "ClusterSecretStore"
          }
          target = {
            name           = "paragon-managed-sync-secrets"
            creationPolicy = "Owner"
          }
          dataFrom = [{
            extract = {
              key = var.managed_sync_secret_name
            }
          }]
        }
      }) : null,
      var.openobserve_secret_name != null ? yamlencode({
        apiVersion = "external-secrets.io/v1beta1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "openobserve-credentials"
          namespace = var.destination_namespace
        }
        spec = {
          refreshInterval = "1h"
          secretStoreRef = {
            name = var.cluster_secret_store_name
            kind = "ClusterSecretStore"
          }
          target = {
            name           = "openobserve-credentials"
            creationPolicy = "Owner"
          }
          dataFrom = [{
            extract = {
              key = var.openobserve_secret_name
            }
          }]
        }
      }) : null,
    ]) : yamldecode(m)
  ]

  # ExternalSecret manifests only contain secret *names* (not values); mark
  # nonsensitive so they are valid for for_each keys.
  external_secret_manifests = nonsensitive({ for idx, doc in local.external_secret_docs : "es-${idx}" => doc })

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

# ESO is installed by eks-blueprints-addons. Parent module time_sleep.gitops_eso_crds
# waits for the Helm release and CRD registration before this module applies manifests.
resource "terraform_data" "eso_crds_ready" {
  input = var.eso_crds_ready
}

# GitOps bridge metadata (EKS Blueprints pattern): annotate the in-cluster
# Argo CD cluster secret so ApplicationSets can read cloud/IAM context.
# https://aws-ia.github.io/terraform-aws-eks-blueprints/patterns/gitops/gitops-getting-started-argocd/
resource "kubernetes_annotations" "gitops_bridge" {
  api_version = "v1"
  kind        = "Secret"

  metadata {
    name      = "${var.argocd_release_name}-cluster"
    namespace = var.argocd_namespace
  }

  annotations = local.gitops_bridge_annotations

  depends_on = [terraform_data.eso_crds_ready]
}

resource "kubernetes_labels" "gitops_bridge" {
  api_version = "v1"
  kind        = "Secret"

  metadata {
    name      = "${var.argocd_release_name}-cluster"
    namespace = var.argocd_namespace
  }

  labels = {
    "aws_cluster_name" = var.cluster_name
    "cluster_name"     = "in-cluster"
    "environment"      = var.workspace
    "enable_argocd"    = "true"
  }

  depends_on = [terraform_data.eso_crds_ready]
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = var.cluster_secret_store_name
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

  depends_on = [terraform_data.eso_crds_ready]
}

resource "kubernetes_manifest" "app_of_apps" {
  count = local.app_of_apps_manifest != null ? 1 : 0

  manifest = yamldecode(local.app_of_apps_manifest)

  depends_on = [
    kubernetes_manifest.cluster_secret_store,
    kubernetes_annotations.gitops_bridge,
    kubernetes_labels.gitops_bridge,
  ]
}

resource "kubernetes_manifest" "external_secrets" {
  for_each = local.external_secret_manifests

  manifest = each.value

  depends_on = [kubernetes_manifest.cluster_secret_store]
}
