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

  microservice_values = yamlencode({
    for microservice_name, microservice_config in var.microservices : microservice_name => {
      env = {
        SERVICE = microservice_name
      }
    }
  })

  # managed-sync chart (useparagon-internal/managed-sync) shared ingress requires root-level
  # tlsSecret on Azure; see k8s/charts/managed-sync/templates/ingress/ingress.yaml
  managed_sync_values = yamlencode({
    tlsSecret = "api-sync-secret"
  })

  public_microservice_values = yamlencode({
    for microservice_name, microservice_config in var.public_microservices : microservice_name => {
      ingress = {
        class     = "nginx" # used for managed sync
        className = "nginx"
        host      = replace(replace(microservice_config.public_url, "https://", ""), "http://", "")
        annotations = {
          "kubernetes.io/ingress.class"    = "nginx"
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        scheme = var.ingress_scheme
      }
      tls_secret = "${microservice_name}-secret"
    }
  })

  monitor_values = yamlencode({
    for monitor_name, monitor_config in var.monitors : monitor_name => {
      image = {
        tag = var.monitor_version
      }
    }
  })

  public_monitor_values = yamlencode({
    for monitor_name, monitor_config in var.public_monitors : monitor_name => {
      ingress = {
        className = "nginx"
        host      = replace(replace(monitor_config.public_url, "https://", ""), "http://", "")
        annotations = {
          "kubernetes.io/ingress.class"    = "nginx"
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        scheme = var.ingress_scheme
      }
      tls_secret = "${monitor_name}-secret"
    }
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
        podAnnotations = merge(
          try(nonsensitive(var.helm_values.global).podAnnotations, {}),
          {
            "reloader.stakater.com/auto" = "true"
          }
        )
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

  runtime_secret_values = yamlencode({
    fluent-bit = {
      envFrom = [
        {
          secretRef = {
            name = "openobserve-credentials"
          }
        }
      ]
      podAnnotations = {
        "reloader.stakater.com/auto" = "true"
      }
    }
    openobserve = {
      secretName = "openobserve-credentials"
    }
  })

  global_values_minus_env = yamlencode(merge(
    nonsensitive(var.helm_values),
    {
      global = merge(
        nonsensitive(var.helm_values).global,
        {
          podAnnotations = merge(
            try(nonsensitive(var.helm_values).global.podAnnotations, {}),
            { "reloader.stakater.com/auto" = "true" }
          )
          env = {
            HOST_ENV = "AZURE_K8"
          }
        },
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

# microservices deployment
resource "helm_release" "paragon_on_prem" {
  name              = "paragon-on-prem"
  description       = "Paragon microservices"
  chart             = "./charts/paragon-onprem"
  version           = "${local.version}-${local.chart_hashes["paragon-onprem"]}"
  namespace         = kubernetes_namespace.paragon.id
  create_namespace  = false
  cleanup_on_fail   = true
  atomic            = true
  force_update      = true
  verify            = false
  timeout           = 900 # 15 minutes
  dependency_update = true

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
    helm_release.ingress,
    data.kubernetes_secret.paragon_secrets,
    data.kubernetes_secret.docker_cfg,
    kubernetes_config_map.feature_flag_content
  ]
}

# paragon logging stack fluent bit and openobserve
resource "helm_release" "paragon_logging" {
  name              = "paragon-logging"
  description       = "Paragon logging services"
  chart             = "./charts/paragon-logging"
  version           = "${local.version}-${local.chart_hashes["paragon-logging"]}"
  namespace         = kubernetes_namespace.paragon.id
  create_namespace  = false
  cleanup_on_fail   = true
  atomic            = true
  force_update      = true
  verify            = false
  timeout           = 900 # 15 minutes
  dependency_update = true

  values = fileexists("${path.root}/../.secure/values.yaml") ? [
    local.helm_values_yaml,
    local.global_values,
    local.runtime_secret_values,
    file("${path.root}/../.secure/values.yaml")
    ] : [
    local.helm_values_yaml,
    local.global_values,
    local.runtime_secret_values
  ]

  set {
    name  = "global.env.ZO_S3_PROVIDER"
    value = "azure"
  }

  set {
    name  = "global.env.ZO_S3_BUCKET_NAME"
    value = var.logs_bucket
  }

  depends_on = [
    helm_release.ingress,
    data.kubernetes_secret.docker_cfg,
    data.kubernetes_secret.openobserve_credentials
  ]
}

# monitors deployment
resource "helm_release" "paragon_monitoring" {
  count = var.monitors_enabled ? 1 : 0

  name              = "paragon-monitoring"
  description       = "Paragon monitors"
  chart             = "./charts/paragon-monitoring"
  version           = "${var.monitor_version}-${local.chart_hashes["paragon-monitoring"]}"
  namespace         = kubernetes_namespace.paragon.id
  cleanup_on_fail   = true
  create_namespace  = false
  atomic            = true
  force_update      = true
  verify            = false
  timeout           = 900 # 15 minutes
  dependency_update = true

  values = [
    local.helm_values_yaml,
    local.subchart_values,
    local.global_values,
    local.monitor_values,
    local.public_monitor_values,
    local.secret_hash
  ]

  depends_on = [
    helm_release.ingress,
    helm_release.paragon_on_prem,
    data.kubernetes_secret.paragon_secrets,
    data.kubernetes_secret.docker_cfg
  ]
}
