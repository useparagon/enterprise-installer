locals {
  # The Agent OS chart owns Enterprise application defaults, migration hooks,
  # Kafka ACLs, Bifrost, models, tools features, scheduling and pod capacity.
  # Terraform supplies only AWS identity, tenant integration and secret rollout.
  agent_os_aws_values = {
    global = {
      agentOs = {
        cloud = "aws"

        imagePullSecrets = var.docker_cfg_secret_name != null ? [
          { name = var.docker_pull_secret_name }
        ] : []

        identity = {
          provider = "aws-pod-identity"
        }

        objectStore = {
          region = var.aws_region
        }

        env = {
          HOST_ENV                              = "AWS_K8"
          PLATFORM_ENV                          = try(var.helm_values.global.env["PLATFORM_ENV"], "enterprise")
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

  }
}

resource "helm_release" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name             = "agent-os"
  description      = "Agent OS"
  repository       = var.agent_os_helm_repository
  chart            = "agent-os"
  version          = var.agent_os_version
  namespace        = local.paragon_namespace
  create_namespace = false
  cleanup_on_fail  = true
  atomic           = true
  verify           = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900 # 15 minutes, consistent with Paragon and Managed Sync

  # Helm owns application defaults; tenant-specific AWS integration is
  # layered before these two override surfaces:
  #   1. Terraform: agent_os_helm_values
  #   2. .secure/values.yaml: agentOs.values (highest precedence)
  values = [
    yamlencode(local.agent_os_aws_values),
    yamlencode(var.agent_os_helm_values),
    yamlencode(var.agent_os_file_values),
  ]

  depends_on = [
    helm_release.managed_sync,
    terraform_data.eso_secrets_gate,
    data.kubernetes_secret.agent_os_app,
    data.kubernetes_secret.agent_os_broker,
    data.kubernetes_secret.agent_os_admin,
    data.kubernetes_secret.docker_cfg,
    kubernetes_service_account.agent_os,
    kubernetes_storage_class_v1.gp3_encrypted,
  ]
}
