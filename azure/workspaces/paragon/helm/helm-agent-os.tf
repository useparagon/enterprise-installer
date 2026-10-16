# The Agent OS chart owns Enterprise application defaults, migration hooks,
# Kafka ACLs, Bifrost, models, tools features, scheduling and pod capacity.
# Terraform supplies only AKS identity, customer endpoints and secret rollout.
# HOST_ENV=AZURE_K8 tells the chart to omit Kafka ACLs for Event Hubs.
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

        env = {
          HOST_ENV                              = "AZURE_K8"
          PLATFORM_ENV                          = try(var.helm_values.global.env["PLATFORM_ENV"], "enterprise")
          PARAGON_ZEUS_URL                      = "http://zeus:${var.microservices["zeus"].port}"
          PARAGON_MANAGED_SYNC_URL              = "http://api-sync:${try(var.microservices["api-sync"].port, var.helm_values.global.env["API_SYNC_HTTP_PORT"], 1800)}"
          PARAGON_MANAGED_SYNC_PROJECT_HOST     = "api-project"
          PARAGON_MANAGED_SYNC_PROJECT_TCP_PORT = tostring(try(var.helm_values.global.env["API_PROJECT_TCP_PORT"], 1805))
          PARAGON_ACTIONKIT_URL                 = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"
          CAPABILITY_BROKER_ACTIONKIT_URL       = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"
          AGENT_OS_SECRET_REVISION              = var.secrets_revision
        }
      }
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
