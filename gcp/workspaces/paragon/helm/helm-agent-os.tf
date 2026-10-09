# The upstream Agent OS chart owns application defaults and service
# scheduling. Keep only GKE/tenant integration and independent overrides here.
locals {
  agent_os_gcp_values = {
    global = {
      agentOs = {
        cloud = "gcp"

        imagePullSecrets = var.create_docker_pull_secret && var.docker_cfg_secret_name != null ? [
          { name = var.docker_pull_secret_name }
        ] : try(nonsensitive(var.helm_values.global.imagePullSecrets), [])

        identity = {
          provider = "gcp"
          gcp = {
            serviceAccountEmail = var.agent_os_service_account
          }
        }

        env = {
          HOST_ENV                              = "GCP_K8"
          NODE_ENV                              = try(var.helm_values.global.env["NODE_ENV"], "production")
          PLATFORM_ENV                          = try(var.helm_values.global.env["PLATFORM_ENV"], "enterprise")
          LOG_LEVEL                             = try(var.helm_values.global.env["LOG_LEVEL"], "info")
          BIFROST_URL                           = "http://agent-os-bifrost:8080"
          PARAGON_ZEUS_URL                      = "http://zeus:${var.microservices["zeus"].port}"
          PARAGON_MANAGED_SYNC_URL              = "http://api-sync:${var.microservices["api-sync"].port}"
          PARAGON_MANAGED_SYNC_PROJECT_HOST     = "api-project"
          PARAGON_MANAGED_SYNC_PROJECT_TCP_PORT = tostring(try(var.helm_values.global.env["API_PROJECT_TCP_PORT"], 1805))
          PARAGON_ACTIONKIT_URL                 = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"
          CAPABILITY_BROKER_ACTIONKIT_URL       = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"
          AGENT_OS_SECRET_REVISION              = var.secrets_revision
        }
      }
    }

    # Provision application PostgreSQL roles before Helm waits for ready pods.
    migration = {
      hookType = "pre-install,pre-upgrade"
    }
    tools-api = {
      migration = {
        hookType = "pre-install,pre-upgrade"
      }
      env = {
        AGENT_OS_TOOL_SEARCH_ENABLED     = "true"
        AGENT_OS_TOOL_EXECUTE_ENABLED    = "true"
        AGENT_OS_EXEC_ALLOW_SIDE_EFFECTS = "true"
      }
    }

    bifrost = {
      enabled = true
    }

    capability-broker = {
      # The broker reads only the least-privilege role and signing credentials.
      secretName          = "agent-os-capability-broker"
      includeGlobalSecret = false
    }

    # Unlike the AWS-only chart defaults, GKE needs explicit scheduling for
    # the tainted Agent OS pools provisioned in infra/cluster.
    index-maintainer = {
      nodeSelector = { "useparagon.com/workload" = "agent-os-index" }
      tolerations = [{
        key      = "useparagon.com/workload"
        operator = "Equal"
        value    = "agent-os-index"
        effect   = "NoSchedule"
      }]
    }
    index-reader = {
      nodeSelector = { "useparagon.com/workload" = "agent-os-index" }
      tolerations = [{
        key      = "useparagon.com/workload"
        operator = "Equal"
        value    = "agent-os-index"
        effect   = "NoSchedule"
      }]
    }
    extraction-service = {
      nodeSelector = { "useparagon.com/workload" = "agent-os-extract" }
      tolerations = [{
        key      = "useparagon.com/workload"
        operator = "Equal"
        value    = "agent-os-extract"
        effect   = "NoSchedule"
      }]
    }
  }
}

resource "helm_release" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name             = "agent-os"
  description      = "Agent OS"
  repository       = var.agent_os_helm_repository
  chart            = "agent-os"
  version          = var.agent_os_version
  namespace        = kubernetes_namespace_v1.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  # Connect Gateway may reject Helm's extra OpenAPI discovery requests.
  disable_openapi_validation = true

  values = [
    yamlencode(local.agent_os_gcp_values),
    yamlencode(var.agent_os_helm_values),
    yamlencode(var.agent_os_file_values),
  ]

  depends_on = [
    helm_release.managed_sync,
    terraform_data.eso_secrets_gate,
    data.kubernetes_secret.agent_os_app,
    data.kubernetes_secret.agent_os_admin,
    data.kubernetes_secret.agent_os_broker,
    data.kubernetes_secret.docker_cfg,
    kubernetes_service_account_v1.agent_os,
    google_service_account_iam_member.agent_os_workload_identity,
  ]
}
