locals {
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

  env_secret_name          = var.env_secret_name
  docker_cfg_secret_name   = var.docker_cfg_secret_name
  managed_sync_secret_name = var.managed_sync_secret_name
  openobserve_secret_name  = var.openobserve_secret_name

  external_secret_docs = [
    for m in compact([
      local.env_secret_name != null ? yamlencode({
        apiVersion = "external-secrets.io/v1beta1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "paragon-secrets"
          namespace = var.destination_namespace
        }
        spec = {
          refreshInterval = "30s"
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
              key = local.env_secret_name
            }
          }]
        }
      }) : null,
      local.docker_cfg_secret_name != null ? yamlencode({
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
              key      = local.docker_cfg_secret_name
              property = "dockerconfigjson"
            }
          }]
        }
      }) : null,
      local.managed_sync_secret_name != null ? yamlencode({
        apiVersion = "external-secrets.io/v1beta1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "paragon-managed-sync-secrets"
          namespace = var.destination_namespace
        }
        spec = {
          refreshInterval = "30s"
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
              key = local.managed_sync_secret_name
            }
          }]
        }
      }) : null,
      local.openobserve_secret_name != null ? yamlencode({
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
              key = local.openobserve_secret_name
            }
          }]
        }
      }) : null,
    ]) : yamldecode(m)
  ]

  external_secret_manifests = nonsensitive({ for idx, doc in local.external_secret_docs : "es-${idx}" => doc })

  gitops_bridge_annotations = merge(
    {
      "aws_region"                  = var.aws_region
      "aws_cluster_name"            = var.cluster_name
      "cluster_name"                = "in-cluster"
      "environment"                 = var.workspace
      "cluster_autoscaler_role_arn" = var.cluster_autoscaler_enabled ? aws_iam_role.cluster_autoscaler[0].arn : ""
      "ingress_scheme"              = var.ingress_scheme
      "paragon_monitors_enabled"    = var.paragon_monitors_enabled ? "true" : "false"
      "managed_sync_enabled"        = var.managed_sync_enabled ? "true" : "false"
    },
    trimspace(var.app_chart_repository) != "" ? {
      app_chart_repository = trimspace(var.app_chart_repository)
    } : {},
    var.paragon_managed_sync_version != null && trimspace(var.paragon_managed_sync_version) != "" ? {
      paragon_managed_sync_version = trimspace(var.paragon_managed_sync_version)
    } : {},
    length(var.secrets_manager_secret_arns) > 0 ? {
      "secrets_manager_prefix" = local.secret_prefix
    } : {},
    trimspace(local.paragon_certificate_arn_resolved) != "" ? {
      paragon_certificate_arn = trimspace(local.paragon_certificate_arn_resolved)
    } : {},
    trimspace(var.paragon_domain) != "" ? {
      paragon_domain = trimspace(var.paragon_domain)
    } : {}
  )
}

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
  count = local.enabled ? 1 : 0

  name             = var.argocd_release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_helm_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
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
    crds = {
      install = true
      keep    = true
    }
  })]

  dynamic "set" {
    for_each = var.argocd_addon_overrides
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "helm_release" "external_secrets" {
  count = local.enabled ? 1 : 0

  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = local.eso_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode(merge({
    installCRDs = true
    crds = {
      createClusterSecretStore    = true
      createClusterExternalSecret = true
      createClusterGenerator      = true
      createPushSecret            = true
    }
    serviceAccount = {
      name = local.eso_sa_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.eso[0].arn
      }
    }
  }, var.eso_addon_overrides))]

  depends_on = [helm_release.argocd]
}

resource "helm_release" "aws_load_balancer_controller" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "3.3.0"
  namespace        = local.lbc_namespace
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [yamlencode(merge(
    {
      clusterName = var.cluster_name
      serviceAccount = {
        name = local.lbc_sa_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller[0].arn
        }
      }
    },
    local.gitops_alb_ingress_class_exists ? {
      createIngressClassResource = false
    } : {}
  ))]

  depends_on = [helm_release.external_secrets]
}

resource "helm_release" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.15.0"
  namespace        = local.external_dns_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    serviceAccount = {
      name = local.external_dns_sa_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns[0].arn
      }
    }
    provider      = "aws"
    policy        = "sync"
    txtOwnerId    = var.workspace
    domainFilters = [trimspace(var.paragon_domain)]
    sources       = ["ingress", "service"]
  })]

  depends_on = [
    helm_release.external_secrets,
    aws_iam_role_policy.external_dns[0],
  ]
}

resource "kubernetes_secret_v1" "gitops_bridge_cluster" {
  count = local.enabled ? 1 : 0

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
    name   = "in-cluster"
    server = "https://kubernetes.default.svc"
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
      }
    })
  }

  depends_on = [time_sleep.eso_crds, helm_release.argocd]
}

resource "kubernetes_secret_v1" "bootstrap_repo" {
  count = local.enabled && local.bootstrap_repo_credential_enabled ? 1 : 0

  metadata {
    name      = "${var.workspace}-bootstrap-repo"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = local.bootstrap_repo_url_trimmed
    username = "x-access-token"
    password = local.bootstrap_repo_token_trimmed
  }

  depends_on = [time_sleep.eso_crds, helm_release.argocd]
}

resource "kubectl_manifest" "cluster_secret_store" {
  count = local.enabled ? 1 : 0

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

  depends_on = [time_sleep.eso_crds, helm_release.external_secrets]
}

resource "kubectl_manifest" "app_of_apps" {
  count = local.enabled && local.app_of_apps_manifest != null ? 1 : 0

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

resource "kubectl_manifest" "destination_namespace" {
  count = local.enabled && length(local.external_secret_manifests) > 0 ? 1 : 0

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
  force_conflicts   = true

  depends_on = [
    kubectl_manifest.cluster_secret_store,
    kubectl_manifest.destination_namespace,
  ]
}
