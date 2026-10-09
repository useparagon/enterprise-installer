# Only AKS/customer integration belongs here. Agent OS owns all shared
# service defaults, resource limits, runtime model defaults and scheduling.
# HOST_ENV=AZURE_K8 deliberately does not enable the AWS-only Helm helpers.
locals {
  agent_os_azure_values = {
    global = {
      agentOs = {
        cloud = "azure"

        imagePullSecrets = var.create_docker_pull_secret && var.docker_cfg_secret_name != null ? [
          { name = var.docker_pull_secret_name }
        ] : try(nonsensitive(var.helm_values.global.imagePullSecrets), [])

        identity = {
          provider = "azure"
          azure = {
            clientId = var.agent_os_workload_identity_client_id
            tenantId = var.external_secrets_tenant_id
          }
        }

        # AZURE_K8 suppresses Kafka CreateAcls on Event Hubs. BIFROST_URL is
        # in-cluster Service DNS; the chart injects it only for AWS_K8.
        env = {
          HOST_ENV                              = "AZURE_K8"
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

    # Same Enterprise feature profile as AWS. VOYAGE_API_KEY must be seeded in
    # the operator-owned agent-os-vendor Key Vault secret before Helm installs.
    bifrost = {
      enabled = true
    }

    # The broker reads only its least-privilege role and signing credentials,
    # same as AWS/GCP (AKS ESO produces a dedicated agent-os-capability-broker Secret).
    capability-broker = {
      secretName          = "agent-os-capability-broker"
      includeGlobalSecret = false
    }

    # AKS needs explicit scheduling for the tainted Agent OS pools provisioned
    # in infra/cluster (aosindex / aosextract); the chart's default affinity targets AWS.
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
  namespace        = kubernetes_namespace.paragon.id
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  # Chart defaults < cloud runtime integration < Terraform overrides
  # < agentOs.values from the customer values.yaml.
  values = [
    yamlencode(local.agent_os_azure_values),
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
    kubernetes_service_account.agent_os,
  ]
}
