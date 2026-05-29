locals {
  eso_namespace = "external-secrets"
  # eks-blueprints-addons names the IRSA service account "{release-name}-sa".
  eso_sa_name = "external-secrets-sa"

  bootstrap_repo_url_trimmed = trimspace(var.bootstrap_repo_url)

  bootstrap_repo_token_trimmed = var.bootstrap_repo_token != null ? trimspace(var.bootstrap_repo_token) : ""

  bootstrap_repo_credential_enabled = (
    local.bootstrap_repo_url_trimmed != "" &&
    startswith(local.bootstrap_repo_url_trimmed, "https://") &&
    local.bootstrap_repo_token_trimmed != ""
  )

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
        annotations = local.bootstrap_repo_credential_enabled ? {
          # Bumps when repo credentials change so Argo CD re-fetches Git after apply.
          "paragon.io/bootstrap-repo-creds-checksum" = sha256(local.bootstrap_repo_token_trimmed)
        } : {}
        finalizers = [
          "resources-finalizer.argocd.argoproj.io",
        ]
      }
      spec = {
        project = "default"
        source = {
          repoURL        = local.bootstrap_repo_url_trimmed
          targetRevision = var.bootstrap_repo_revision
          path           = trimspace(var.bootstrap_repo_path)
          directory = {
            recurse = true
          }
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

# GitOps bridge metadata (EKS Blueprints pattern): create the in-cluster Argo CD cluster
# secret so ApplicationSets can read cloud/IAM context. Blueprints installs Argo CD but
# does not create this secret; annotating a non-existent resource fails at apply time.
# https://aws-ia.github.io/terraform-aws-eks-blueprints/patterns/gitops/gitops-getting-started-argocd/
resource "kubernetes_secret_v1" "gitops_bridge_cluster" {
  metadata {
    name      = "${var.argocd_release_name}-cluster"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "aws_cluster_name"               = var.cluster_name
      "cluster_name"                   = "in-cluster"
      "environment"                    = var.workspace
      "enable_argocd"                  = "true"
    }
    annotations = local.gitops_bridge_annotations
  }

  type = "Opaque"

  data = {
    name   = base64encode("in-cluster")
    server = base64encode("https://kubernetes.default.svc")
    config = base64encode(jsonencode({
      tlsClientConfig = {
        insecure = false
      }
    }))
  }

  depends_on = [terraform_data.eso_crds_ready]
}

# Argo CD repository credential (GitHub PAT over HTTPS). Username is fixed to `git`;
# password is the PAT. Same secret covers bootstrap + ApplicationSet $values refs.
resource "kubernetes_secret_v1" "bootstrap_repo" {
  count = local.bootstrap_repo_credential_enabled ? 1 : 0

  metadata {
    name      = "${var.workspace}-bootstrap-repo"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  # data values are base64-encoded for the Kubernetes API (provider does not re-encode).
  # GitHub PAT: username x-access-token, password = PAT.
  data = {
    type     = base64encode("git")
    url      = base64encode(local.bootstrap_repo_url_trimmed)
    username = base64encode("x-access-token")
    password = base64encode(local.bootstrap_repo_token_trimmed)
  }

  depends_on = [terraform_data.eso_crds_ready]
}

# Custom resources use kubectl_manifest (server-side apply, applied at apply-time) so the
# plan does not require the CRDs to already exist on the cluster. The CRDs are installed by
# eks-blueprints-addons earlier in the same apply; terraform_data.eso_crds_ready gates ordering.
resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = yamlencode({
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
  })

  server_side_apply = true
  wait              = true

  depends_on = [terraform_data.eso_crds_ready]
}

resource "kubectl_manifest" "app_of_apps" {
  count = local.app_of_apps_manifest != null ? 1 : 0

  yaml_body = local.app_of_apps_manifest

  server_side_apply = true

  lifecycle {
    replace_triggered_by = [
      kubernetes_secret_v1.bootstrap_repo,
    ]
  }

  depends_on = [
    kubectl_manifest.cluster_secret_store,
    kubernetes_secret_v1.gitops_bridge_cluster,
    kubernetes_secret_v1.bootstrap_repo,
  ]
}

# ExternalSecrets live in the destination namespace. Create it (server-side apply adopts an
# existing namespace on brownfield clusters) so the CRs have a namespace to land in.
resource "kubectl_manifest" "destination_namespace" {
  count = length(local.external_secret_manifests) > 0 ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = var.destination_namespace
    }
  })

  server_side_apply = true
}

resource "kubectl_manifest" "external_secrets" {
  for_each = local.external_secret_manifests

  yaml_body = yamlencode(each.value)

  server_side_apply = true

  depends_on = [
    kubectl_manifest.cluster_secret_store,
    kubectl_manifest.destination_namespace,
  ]
}
