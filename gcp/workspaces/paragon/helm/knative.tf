# Knative Serving + Kourier. Required before paragon-on-prem can apply
# ocs-code-runner (serving.knative.dev/v1 Service). Kourier is ClusterIP so
# apply does not provision a public load balancer; workers call the cluster-local URL.

resource "kubernetes_namespace_v1" "knative_operator" {
  metadata {
    name = "knative-operator"
  }
}

resource "helm_release" "knative_operator" {
  name             = "knative-operator"
  namespace        = kubernetes_namespace_v1.knative_operator.metadata[0].name
  repository       = "https://knative.github.io/operator"
  chart            = "knative-operator"
  version          = "v1.23.1"
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 600
}

resource "kubernetes_namespace_v1" "knative_serving" {
  metadata {
    name = "knative-serving"
  }
}

locals {
  knative_image_pull_data     = try(data.kubernetes_secret.docker_cfg[0].data, tomap({}))
  knative_serving_pull_secret = var.create_docker_pull_secret && length(local.knative_image_pull_data) > 0
}

# Same docker-cfg as paragon workloads. Knative's revision controller lives in
# this namespace and resolves tags with remote.Head; it will not see the
# paragon-namespace secret unless it is mounted here via spec.registry.
resource "kubernetes_secret_v1" "knative_serving_image_pull" {
  count = local.knative_serving_pull_secret ? 1 : 0

  metadata {
    name      = var.docker_pull_secret_name
    namespace = kubernetes_namespace_v1.knative_serving.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"
  data = local.knative_image_pull_data
}

resource "kubectl_manifest" "knative_serving" {
  yaml_body = yamlencode({
    apiVersion = "operator.knative.dev/v1beta1"
    kind       = "KnativeServing"
    metadata = {
      name      = "knative-serving"
      namespace = kubernetes_namespace_v1.knative_serving.metadata[0].name
    }
    spec = merge(
      {
        ingress = {
          kourier = {
            enabled        = true
            "service-type" = "ClusterIP"
          }
        }
        config = {
          network = {
            ingress-class = "kourier.ingress.networking.knative.dev"
          }
          # Serving 1.23 digest resolution uses HTTP HEAD. Docker Hub returns 401
          # for private repos even with a valid keychain; kubelet still pulls with
          # imagePullSecrets. Skip Hub so ocs-code-runner (always docker.io) can
          # become Ready. Other registries still pin digests.
          deployment = {
            "registries-skipping-tag-resolving" = "kind.local,ko.local,dev.local,index.docker.io,docker.io"
          }
          # Default is OTLP http/protobuf. Grafana knative-ocs needs Prom series
          # (kn_revision_*, queue-proxy request counters on :9091).
          observability = {
            "metrics-protocol"         = "prometheus"
            "request-metrics-protocol" = "prometheus"
          }
        }
        # For annotation-based (prometheus.io/scrape) discovery of autoscaler/activator :9090.
        deployments = [
          {
            name = "autoscaler"
            annotations = {
              "prometheus.io/scrape" = "true"
              "prometheus.io/port"   = "9090"
              "prometheus.io/path"   = "/metrics"
            }
          },
          {
            name = "activator"
            annotations = {
              "prometheus.io/scrape" = "true"
              "prometheus.io/port"   = "9090"
              "prometheus.io/path"   = "/metrics"
            }
          },
        ]
      },
      local.knative_serving_pull_secret ? {
        registry = {
          imagePullSecrets = [{
            name = var.docker_pull_secret_name
          }]
        }
      } : {}
    )
  })

  depends_on = [
    helm_release.knative_operator,
    kubernetes_secret_v1.knative_serving_image_pull,
  ]
}

# Operator installs serving.knative.dev only after this CR is applied. Poll
# KnativeServing Ready so paragon-on-prem does not apply a ksvc early.
resource "terraform_data" "knative_serving_ready" {
  depends_on = [kubectl_manifest.knative_serving]

  input = sha256(kubectl_manifest.knative_serving.yaml_body)

  provisioner "local-exec" {
    command = "sh ${path.module}/../../../../scripts/wait-knative-serving.sh"
    environment = {
      KNATIVE_API_HOST = local.cluster.host
      KNATIVE_TOKEN    = local.cluster.token
    }
  }
}
