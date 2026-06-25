locals {
  eso_namespace = "external-secrets"
  eso_sa_name   = "external-secrets"

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

  app_of_apps_manifest = (
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

  # Module-internal secret name derivation — mirrors the names created in secrets.tf.
  env_secret_name          = local.secrets_ready ? "${var.workspace}-env" : null
  docker_cfg_secret_name   = local.secrets_ready ? "${var.workspace}-docker-cfg" : null
  managed_sync_secret_name = local.secrets_ready && var.managed_sync_config != null ? "${var.workspace}-managed-sync" : null
  openobserve_secret_name  = local.secrets_ready ? "${var.workspace}-openobserve" : null

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
      local.secrets_ready ? yamlencode({
        apiVersion = "external-secrets.io/v1beta1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "redis-ca-cert"
          namespace = var.destination_namespace
        }
        spec = {
          refreshInterval = "1h"
          secretStoreRef = {
            name = var.cluster_secret_store_name
            kind = "ClusterSecretStore"
          }
          target = {
            name           = "redis-ca-cert"
            creationPolicy = "Owner"
          }
          data = [{
            secretKey = "server-ca.pem"
            remoteRef = {
              key      = "${var.workspace}-redis-ca-cert"
              property = "server-ca.pem"
            }
          }]
        }
      }) : null,
    ]) : yamldecode(m)
  ]

  external_secret_manifests = nonsensitive({ for idx, doc in local.external_secret_docs : "es-${idx}" => doc })

  gitops_bridge_annotations = merge(
    {
      "gcp_project_id"           = var.gcp_project_id
      "gcp_region"               = var.gcp_region
      "gcp_cluster_name"         = var.cluster_name
      "cluster_name"             = "in-cluster"
      "environment"              = var.workspace
      "ingress_scheme"           = var.ingress_scheme
      "paragon_monitors_enabled" = var.paragon_monitors_enabled ? "true" : "false"
      "managed_sync_enabled"     = var.managed_sync_enabled ? "true" : "false"
      "secret_manager_prefix"    = var.workspace
    },
    trimspace(var.app_chart_repository) != "" ? {
      app_chart_repository = trimspace(var.app_chart_repository)
    } : {},
    var.paragon_managed_sync_version != null && trimspace(var.paragon_managed_sync_version) != "" ? {
      paragon_managed_sync_version = trimspace(var.paragon_managed_sync_version)
    } : {},
    trimspace(var.paragon_domain) != "" ? {
      paragon_domain = trimspace(var.paragon_domain)
    } : {}
  )
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
  wait_for_jobs    = true
  timeout          = 600

  values = [
    yamlencode(merge(
      {
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
      },
      var.argocd_addon_overrides
    ))
  ]

  depends_on = [time_sleep.eso_crds]
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
  wait_for_jobs    = true
  timeout          = 600

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      annotations = {
        "iam.gke.io/gcp-service-account" = google_service_account.eso[0].email
      }
    }
    crds = {
      createClusterSecretStore    = true
      createClusterExternalSecret = true
      createClusterGenerator      = true
      createPushSecret            = true
    }
  })]

  depends_on = [time_sleep.eso_crds]
}

resource "helm_release" "external_dns" {
  count = local.gitops_ingress_enabled ? 1 : 0

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.15.0"
  namespace        = "external-dns"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [yamlencode({
    provider = {
      name = "google"
    }
    google = {
      project = var.gcp_project_id
    }
    serviceAccount = {
      annotations = {
        "iam.gke.io/gcp-service-account" = google_service_account.external_dns[0].email
      }
    }
    policy        = "sync"
    txtOwnerId    = var.workspace
    domainFilters = [var.paragon_domain]
    sources       = ["ingress", "service", "gateway-httproute"]
  })]

  depends_on = [time_sleep.eso_crds]
}

resource "kubernetes_secret_v1" "gitops_bridge_cluster" {
  count = local.enabled ? 1 : 0

  metadata {
    name      = "${var.argocd_release_name}-cluster"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "gcp_cluster_name"               = var.cluster_name
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

  depends_on = [
    helm_release.argocd,
    time_sleep.eso_crds,
  ]
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

  depends_on = [
    helm_release.argocd,
    time_sleep.eso_crds,
  ]
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
        gcpsm = {
          projectID = var.gcp_project_id
          auth = {
            workloadIdentity = {
              clusterLocation  = var.gcp_region
              clusterName      = var.cluster_name
              clusterProjectID = var.gcp_project_id
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

  depends_on = [
    helm_release.external_secrets,
    time_sleep.eso_crds,
  ]
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
  # local.enabled is always true here (module is count-gated on argocd_enabled),
  # so iterate the manifests directly — matching the AWS module. The previous
  # `local.enabled ? ... : {}` ternary broke plan with inconsistent branch types
  # (object-with-attrs vs empty object) and undeterminable for_each keys.
  for_each = local.external_secret_manifests

  yaml_body = yamlencode(each.value)

  server_side_apply = true
  force_conflicts   = true

  depends_on = [
    kubectl_manifest.cluster_secret_store,
    kubectl_manifest.destination_namespace,
  ]
}
