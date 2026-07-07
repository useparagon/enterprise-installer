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

  public_microservice_values = yamlencode({
    for microservice_name, microservice_config in var.public_microservices : microservice_name => {
      ingress = {
        enabled = false
        # values below would only be needed if per service load balancers are desired
        # certificate      = google_compute_managed_ssl_certificate.cert.name
        # className        = var.ingress_scheme == "internal" ? "gce-internal" : "gce"
        # host             = replace(microservice_config.public_url, "https://", "")
        # frontendConfig   = google_compute_region_url_map.frontend_config.name
        # loadBalancerIP   = google_compute_global_address.loadbalancer.address
        # loadBalancerName = google_compute_global_address.loadbalancer.name
        # scheme           = var.ingress_scheme
      }
      service = {
        type = "NodePort"
      }
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
        enabled = false
        # values below would only be needed if per service load balancers are desired
        # certificate      = google_compute_managed_ssl_certificate.cert.name
        # className        = var.ingress_scheme == "internal" ? "gce-internal" : "gce"
        # host             = replace(replace(monitor_config.public_url, "https://", ""), "http://", "")
        # frontendConfig   = google_compute_region_url_map.frontend_config.name
        # loadBalancerIP   = google_compute_global_address.loadbalancer.address
        # loadBalancerName = google_compute_global_address.loadbalancer.name
        # scheme           = var.ingress_scheme
      }
      service = merge(
        {
          type = "NodePort"
        },
        monitor_name == "grafana" ? {
          annotations = {
            "cloud.google.com/backend-config" = jsonencode({
              default = "grafana-backendconfig"
            })
          }
        } : {}
      )
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
              name = kubernetes_config_map_v1.feature_flag_content[0].metadata[0].name
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

  # Managed-sync services only when enabled (avoids IAM bindings for SAs that don't exist).
  cloud_storage_services = concat(
    var.managed_sync_enabled ? ["api-sync", "worker-sync", "worker-history-sync"] : [],
    [
      "api-triggerkit",
      "cache-replay",
      "hades",
      "health-checker",
      "hermes",
      "openobserve",
      "release",
      "worker-actionkit",
      "worker-actions",
      "worker-credentials",
      "worker-crons",
      "worker-deployments",
      "worker-proxy",
      "worker-triggers",
      "worker-triggerkit",
      "worker-workflows",
      "zeus"
    ]
  )

  service_account_values = {
    # merge existing service values and inject service account config
    for service_name in local.cloud_storage_services : service_name => merge(
      try(nonsensitive(var.helm_values)[service_name], {}),
      {
        serviceAccount = {
          create = true
          annotations = {
            "iam.gke.io/gcp-service-account" = var.storage_service_account
          }
        }
      }
    )
    if var.storage_service_account != null
  }

  docker_pull_secret_global_values = var.create_docker_pull_secret ? {
    imagePullSecrets = concat(
      try(nonsensitive(var.helm_values.global.imagePullSecrets), []),
      [{ name = var.docker_pull_secret_name }]
    )
  } : {}

  global_values = yamlencode(merge(
    local.service_account_values,
    {
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
    }
  ))

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
      credsSecretName = var.openobserve_gcs_secret_name != null ? "openobserve-creds" : ""
      secretName      = "openobserve-credentials"
    }
  })

  # helm_values with only global.env.HOST_ENV for managed_sync (repo chart).
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
          env = { HOST_ENV = "GCP_K8" }
        },
        local.docker_pull_secret_global_values
      )
    }
  ))

  # Workload Identity (GCS) for services deployed by the managed-sync chart. Without this,
  # api-sync, worker-sync, worker-history-sync get "storage.buckets.get denied".
  # Use for+if so both branches have the same map type (avoids "inconsistent conditional result types").
  managed_sync_storage_values = {
    for k in ["api-sync", "worker-sync", "worker-history-sync"] :
    k => local.service_account_values[k]
    if var.storage_service_account != null && var.managed_sync_enabled
  }

  # changes to secrets should trigger redeploy
  secret_hash = yamlencode({
    secret_hash = sha256(jsonencode(nonsensitive(var.helm_values)))
  })
}

# creates the `paragon` namespace
resource "kubernetes_namespace_v1" "paragon" {
  metadata {
    name = "paragon"

    annotations = {
      name = "paragon"
    }
  }
}

resource "kubernetes_config_map_v1" "feature_flag_content" {
  count = var.feature_flags_content != null ? 1 : 0

  metadata {
    name      = "feature-flags-content"
    namespace = kubernetes_namespace_v1.paragon.id
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
  namespace         = kubernetes_namespace_v1.paragon.id
  create_namespace  = false
  cleanup_on_fail   = true
  atomic            = true
  verify            = false
  timeout           = 900 # 15 minutes
  dependency_update = true
  force_update      = true

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
    kubectl_manifest.external_secret_docker,
    kubectl_manifest.external_secret_paragon,
    kubernetes_config_map_v1.feature_flag_content,
    kubectl_manifest.external_secret_redis_ca
  ]
}

# paragon logging stack fluent bit and openobserve
resource "helm_release" "paragon_logging" {
  name              = "paragon-logging"
  description       = "Paragon logging services"
  chart             = "./charts/paragon-logging"
  version           = "${local.version}-${local.chart_hashes["paragon-logging"]}"
  namespace         = kubernetes_namespace_v1.paragon.id
  create_namespace  = false
  cleanup_on_fail   = true
  atomic            = true
  verify            = false
  timeout           = 900 # 15 minutes
  dependency_update = true
  force_update      = true

  values = [
    local.helm_values_yaml,
    local.global_values,
    local.runtime_secret_values
  ]

  set {
    name  = "openobserve.env.ZO_S3_BUCKET_NAME"
    value = var.logs_bucket
  }

  set {
    name  = "openobserve.env.ZO_S3_REGION_NAME"
    value = var.region
  }

  dynamic "set" {
    for_each = var.openobserve_gcs_secret_name != null ? [1] : []
    content {
      name  = "openobserve.secrets.ZO_S3_ACCESS_KEY"
      value = "/creds/creds.json"
    }
  }

  set {
    name  = "openobserve.env.ZO_S3_PROVIDER"
    value = "gcs"
  }

  set {
    name  = "openobserve.env.ZO_S3_SERVER_URL"
    value = "https://storage.googleapis.com"
  }

  depends_on = [
    kubectl_manifest.external_secret_docker,
    kubectl_manifest.external_secret_paragon,
    kubectl_manifest.external_secret_openobserve,
    kubectl_manifest.external_secret_openobserve_gcs,
    kubectl_manifest.external_secret_redis_ca
  ]
}

# monitors deployment
resource "helm_release" "paragon_monitoring" {
  count = var.monitors_enabled ? 1 : 0

  name              = "paragon-monitoring"
  description       = "Paragon monitors"
  chart             = "./charts/paragon-monitoring"
  version           = "${var.monitor_version}-${local.chart_hashes["paragon-monitoring"]}"
  namespace         = kubernetes_namespace_v1.paragon.id
  cleanup_on_fail   = true
  create_namespace  = false
  atomic            = true
  verify            = false
  timeout           = 900 # 15 minutes
  dependency_update = true
  force_update      = true

  values = [
    local.helm_values_yaml,
    local.subchart_values,
    local.global_values,
    local.monitor_values,
    local.public_monitor_values,
    local.secret_hash
  ]

  depends_on = [
    helm_release.paragon_on_prem,
    kubectl_manifest.external_secret_docker,
    kubectl_manifest.external_secret_paragon,
    kubectl_manifest.grafana_backendconfig
  ]
}
