locals {
  # Application defaults (models, AWS node placement, resources) come from
  # the chart published after PR #113. Terraform supplies tenant endpoints,
  # identity and feature switches; capacity stays on chart defaults.
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

        # BIFROST_URL is in-cluster Service DNS, same as PARAGON_ZEUS_URL.
        # The chart injects it only when HOST_ENV=AWS_K8.
        env = {
          HOST_ENV                              = try(var.helm_values.global.env["HOST_ENV"], "AWS_K8")
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

    # Match Managed Sync's Enterprise pattern: provision PostgreSQL roles and
    # schemas before Helm waits for application Deployments to become healthy.
    # Both hooks are supported by the currently published Agent OS chart.
    migration = {
      hookType = "pre-install,pre-upgrade"
    }

    # Helm dependency conditions cannot be derived from HOST_ENV templates.
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

    # Opt-in feature profile requires this explicit dependency switch.
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
