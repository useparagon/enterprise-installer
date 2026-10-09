locals {
  # Helm owns application defaults (models, Bifrost URL, node placement,
  # resources, service settings and migration behavior) since agent-os PR #113.
  # Keep only customer-specific AWS integration and opt-in chart features here.
  agent_os_aws_values = {
    global = {
      agentOs = {
        cloud = "aws"

        # The customer may bring an existing pull secret (or no secret).
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
          PLATFORM_ENV                          = "enterprise"
          PARAGON_ZEUS_URL                      = "http://zeus:${var.microservices["zeus"].port}"
          PARAGON_MANAGED_SYNC_URL              = "http://api-sync:${var.microservices["api-sync"].port}"
          PARAGON_MANAGED_SYNC_PROJECT_HOST     = "api-project"
          PARAGON_MANAGED_SYNC_PROJECT_TCP_PORT = tostring(try(var.helm_values.global.env["API_PROJECT_TCP_PORT"], 1805))
          PARAGON_ACTIONKIT_URL                 = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"
          CAPABILITY_BROKER_ACTIONKIT_URL       = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"

          # Secret-only updates must rotate the release even when chart values
          # other than this revision are unchanged.
          AGENT_OS_SECRET_REVISION = var.secrets_revision
        }
      }
    }

    # These are Enterprise AWS feature switches. Helm cannot dynamically
    # enable optional dependencies (Bifrost) from the HOST_ENV template.
    # VOYAGE_API_KEY is sourced from the operator-owned app Secret, not values.
    tools-api = {
      env = {
        AGENT_OS_TOOL_SEARCH_ENABLED     = "true"
        AGENT_OS_TOOL_EXECUTE_ENABLED    = "true"
        AGENT_OS_EXEC_ALLOW_SIDE_EFFECTS = "true"
      }
    }
    bifrost = {
      enabled = true
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
  timeout          = 1800

  # Helm owns its own application defaults. These values contain only AWS
  # integration/feature switches, followed by two explicit override surfaces:
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
