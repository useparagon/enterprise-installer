locals {
  version = var.helm_values.global.env["VERSION"]

  helm_values_yaml = yamlencode(nonsensitive(var.helm_values))

  subchart_values = yamlencode({
    subchart = merge(
      merge(
        {
          for microservice in keys(var.microservices) : microservice => {
            enabled = true
          }
        },
        {
          kafka-exporter = {
            enabled = var.managed_sync_enabled
          }
        }
      ),
      try(nonsensitive(var.helm_values.subchart), {})
    )
  })

  flipt_values = yamlencode({
    flipt = {
      flipt = {
        extraEnvVars = [
          for k, v in var.flipt_options : {
            name  = k
            value = v
          }
        ]
      }
      persistence = var.feature_flags_content != null ? {
        enabled = true
      } : {}
      extraVolumes = var.feature_flags_content != null ? [
        {
          name = "feature-flags-content"
          configMap = {
            name = kubernetes_config_map.feature_flag_content[0].metadata[0].name
          }
        }
      ] : []
      extraVolumeMounts = var.feature_flags_content != null ? [
        {
          name      = "feature-flags-content"
          mountPath = "/var/opt/flipt/production/features.yml"
          subPath   = "features.yml"
          readOnly  = true
        }
      ] : []
    }
  })

  microservice_values = yamlencode({
    for microservice_name, microservice_config in var.microservices : microservice_name => {
      env = {
        SERVICE = microservice_name
      }
    }
  })

  public_microservice_values = yamlencode({
    for microservice_name, microservice_config in var.public_microservices : microservice_name => {
      ingress = merge(
        {
          className          = "alb"
          host               = replace(replace(microservice_config.public_url, "https://", ""), "http://", "")
          scheme             = var.ingress_scheme
          certificate        = var.certificate
          load_balancer_name = var.workspace
          logs_bucket        = var.logs_bucket
        },
        var.waf_web_acl_arn != "" ? { wafv2_acl_arn = var.waf_web_acl_arn } : {}
      )
    }
  })

  monitor_values = yamlencode({
    for monitor_name, monitor_config in var.monitors : monitor_name => {
      image = {
        tag = var.monitor_version
      }
      ingress = {
        logs_bucket = var.logs_bucket
      }
    }
  })

  public_monitor_values = yamlencode({
    for monitor_name, monitor_config in var.public_monitors : monitor_name => {
      ingress = merge(
        {
          className          = "alb"
          host               = replace(replace(monitor_config.public_url, "https://", ""), "http://", "")
          scheme             = var.ingress_scheme
          certificate        = var.certificate
          load_balancer_name = var.workspace
        },
        var.waf_web_acl_arn != "" ? { wafv2_acl_arn = var.waf_web_acl_arn } : {}
      )
    }
  })

  docker_pull_secret_global_values = var.create_docker_pull_secret ? {
    imagePullSecrets = concat(
      try(nonsensitive(var.helm_values.global.imagePullSecrets), []),
      [{ name = var.docker_pull_secret_name }]
    )
  } : {}

  global_values = yamlencode({
    global = merge(
      nonsensitive(var.helm_values.global),
      {
        env = merge(
          nonsensitive(var.helm_values.global.env),
          {
            k8s_version = var.k8s_version
            secretName  = "paragon-secrets"
          }
        ),
        paragon_version = local.version
      },
      local.docker_pull_secret_global_values
    )
  })

  global_values_minus_env = yamlencode(merge(
    nonsensitive(var.helm_values),
    {
      global = merge(
        nonsensitive(var.helm_values).global,
        { env = {
          HOST_ENV = "AWS_K8"
        } },
        local.docker_pull_secret_global_values
      )
    }
  ))

  # changes to secrets should trigger redeploy
  secret_hash = yamlencode({
    secret_hash = sha256(jsonencode(nonsensitive(var.helm_values)))
  })
}

# creates the `paragon` namespace
resource "kubernetes_namespace" "paragon" {
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

resource "kubernetes_config_map" "feature_flag_content" {
  count = var.feature_flags_content != null ? 1 : 0

  metadata {
    name      = "feature-flags-content"
    namespace = kubernetes_namespace.paragon.id
  }

  data = {
    "features.yml" = var.feature_flags_content
  }
}

# kubernetes secret to pull container images from a registry (Docker Hub, Artifactory, etc.)
resource "kubernetes_secret" "docker_login" {
  count = var.create_docker_pull_secret ? 1 : 0

  metadata {
    name      = var.docker_pull_secret_name
    namespace = kubernetes_namespace.paragon.id
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.docker_registry_server}" = {
          "username" = var.docker_username
          "password" = var.docker_password
          "email"    = var.docker_email
          "auth"     = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  }
}

# shared secrets
resource "kubernetes_secret" "paragon_secrets" {
  for_each = toset(
    var.managed_sync_enabled ? [
      "paragon-secrets",
      "paragon-managed-sync-secrets"
      ] : [
      "paragon-secrets"
    ]
  )
  metadata {
    name      = each.value
    namespace = kubernetes_namespace.paragon.id
  }

  type = "Opaque"

  data = {
    # Map global.env from helm_values into secret data
    for key, value in nonsensitive(var.helm_values.global.env) :
    key => value
  }
}

# ingress controller; provisions load balancer
#
# Upgrade order (per cluster, before paragon terraform apply):
#   1. kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
#   2. terraform apply (paragon workspace)
# CRD apply is safe while v2.x controller is still running; skip risks v3.4 crash-loop.
#
# Scheduling: prefer on-demand nodes but allow spot when the on-demand pool is small.
# Pod anti-affinity (preferred) spreads replicas across hosts. PDB + safe-to-evict: false
# protect against cluster-autoscaler disruption regardless of node pool.
resource "helm_release" "ingress" {
  name        = "ingress"
  description = "AWS Ingress Controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.4.0"

  namespace        = kubernetes_namespace.paragon.id
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = false
  force_update     = true
  verify           = false

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "replicaCount"
    value = "3"
  }

  set {
    name  = "podDisruptionBudget.maxUnavailable"
    value = "1"
  }

  # Custom affinity replaces chart default (configureDefaultAffinity); include both
  # preferred on-demand placement and preferred per-host spread.
  values = [yamlencode({
    configureDefaultAffinity = false
    podAnnotations = {
      "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
    }
    affinity = {
      nodeAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [{
          weight = 100
          preference = {
            matchExpressions = [{
              key      = "useparagon.com/capacityType"
              operator = "In"
              values   = ["ondemand"]
            }]
          }
        }]
      }
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [{
          weight = 100
          podAffinityTerm = {
            labelSelector = {
              matchExpressions = [{
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["aws-load-balancer-controller"]
              }]
            }
            topologyKey = "kubernetes.io/hostname"
          }
        }]
      }
    }
  })]
  
  depends_on = [module.karpenter]
}

# metrics server for hpa
resource "helm_release" "metricsserver" {
  name        = "metricsserver"
  description = "AWS Metrics Server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"

  namespace        = kubernetes_namespace.paragon.id
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = false
  force_update     = true
  verify           = false

  depends_on = [
    module.karpenter,
    helm_release.ingress,
  ]
}

# graceful handling of spot evictions on legacy managed node groups
module "aws_node_termination_handler" {
  count = var.enable_legacy_mng_pools ? 1 : 0

  source  = "qvest-digital/aws-node-termination-handler/kubernetes"
  version = "4.0.0"

  json_logging = true

  # Spot nodes are labeled in infra (cluster.tf); avoid legacy lifecycle=Ec2Spot default.
  k8s_node_selector = {
    "useparagon.com/capacityType" = "spot"
  }
  k8s_node_tolerations = []
}

# microservices deployment
resource "helm_release" "paragon_on_prem" {
  name        = "paragon-on-prem"
  description = "Paragon microservices"
  chart       = "./charts/paragon-onprem"
  version     = "${local.version}-${local.chart_hashes["paragon-onprem"]}"

  namespace         = kubernetes_namespace.paragon.id
  atomic            = true
  cleanup_on_fail   = true
  create_namespace  = false
  dependency_update = true
  force_update      = true
  timeout           = 900 # 15 minutes
  verify            = false

  values = [
    local.helm_values_yaml,
    local.subchart_values,
    local.global_values,
    local.flipt_values,
    local.microservice_values,
    local.public_microservice_values,
    local.secret_hash
  ]

  depends_on = [
    module.karpenter,
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_secret.paragon_secrets,
    kubernetes_storage_class_v1.gp3_encrypted,
    kubernetes_config_map.feature_flag_content,
  ]
}

# paragon logging stack fluent bit and openobserve
resource "helm_release" "paragon_logging" {
  name        = "paragon-logging"
  description = "Paragon logging services"
  chart       = "./charts/paragon-logging"
  version     = "${local.version}-${local.chart_hashes["paragon-logging"]}"

  namespace         = kubernetes_namespace.paragon.id
  atomic            = true
  cleanup_on_fail   = true
  create_namespace  = false
  dependency_update = true
  force_update      = true
  timeout           = 900 # 15 minutes
  verify            = false

  values = [
    local.helm_values_yaml,
    local.global_values
  ]

  set {
    name  = "global.env.ZO_S3_PROVIDER"
    value = "s3"
  }

  set {
    name  = "global.env.ZO_S3_BUCKET_NAME"
    value = var.logs_bucket
  }

  set {
    name  = "global.env.ZO_S3_REGION_NAME"
    value = var.aws_region
  }

  set_sensitive {
    name  = "fluent-bit.secrets.ZO_ROOT_USER_EMAIL"
    value = local.openobserve_email
  }

  set_sensitive {
    name  = "fluent-bit.secrets.ZO_ROOT_USER_PASSWORD"
    value = local.openobserve_password
  }

  set_sensitive {
    name  = "openobserve.secrets.ZO_ROOT_USER_EMAIL"
    value = local.openobserve_email
  }

  set_sensitive {
    name  = "openobserve.secrets.ZO_ROOT_USER_PASSWORD"
    value = local.openobserve_password
  }

  depends_on = [
    module.karpenter,
    helm_release.ingress,
    kubernetes_secret.docker_login,
    kubernetes_storage_class_v1.gp3_encrypted,
  ]
}

# monitors deployment
resource "helm_release" "paragon_monitoring" {
  count = var.monitors_enabled ? 1 : 0

  name        = "paragon-monitoring"
  description = "Paragon monitors"
  chart       = "./charts/paragon-monitoring"
  version     = "${var.monitor_version}-${local.chart_hashes["paragon-monitoring"]}"

  namespace         = kubernetes_namespace.paragon.id
  atomic            = true
  cleanup_on_fail   = true
  create_namespace  = false
  dependency_update = true
  force_update      = true
  timeout           = 900 # 15 minutes
  verify            = false

  values = [
    local.helm_values_yaml,
    local.subchart_values,
    local.global_values,
    local.monitor_values,
    local.public_monitor_values,
    local.secret_hash
  ]

  set {
    name  = "global.env.k8s_version"
    value = var.k8s_version
  }

  set {
    name  = "grafana.secrets.MONITOR_GRAFANA_ALB_ARN"
    value = data.aws_lb.load_balancer.arn_suffix
  }

  depends_on = [
    module.karpenter,
    helm_release.ingress,
    helm_release.paragon_on_prem,
    kubernetes_secret.docker_login,
    kubernetes_storage_class_v1.gp3_encrypted,
  ]
}
