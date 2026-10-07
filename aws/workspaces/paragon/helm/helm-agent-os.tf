locals {
  # Installer-owned AWS defaults. Keep environment-specific tuning out of this
  # object: Terraform and .secure/values.yaml are layered after it so customers
  # can override any chart value without editing the module.
  agent_os_aws_values = {
    global = {
      agentOs = {
        image = {
          registry   = "docker.io"
          pullPolicy = "IfNotPresent"
        }

        imagePullSecrets = var.docker_cfg_secret_name != null ? [
          { name = var.docker_pull_secret_name }
        ] : []

        secretName      = "agent-os-app"
        adminSecretName = "agent-os-admin"
        cloud           = "aws"

        serviceAccount = {
          name                         = "agent-os"
          automountServiceAccountToken = true
        }

        identity = {
          provider = "aws-pod-identity"
        }

        # Bucket names and credentials are injected by the Agent OS application
        # Secret. Values only describe the AWS SDK/object-store behavior.
        objectStore = {
          endpoint  = ""
          region    = var.aws_region
          allowHttp = false
          credentials = {
            secretName = ""
          }
        }

        env = {
          HOST_ENV                              = "AWS_K8"
          NODE_ENV                              = "production"
          PLATFORM_ENV                          = "enterprise"
          LOG_LEVEL                             = try(var.helm_values.global.env["LOG_LEVEL"], "info")
          PARAGON_ZEUS_URL                      = "http://zeus:${var.microservices["zeus"].port}"
          PARAGON_MANAGED_SYNC_URL              = "http://api-sync:${var.microservices["api-sync"].port}"
          PARAGON_MANAGED_SYNC_PROJECT_HOST     = "api-project"
          PARAGON_MANAGED_SYNC_PROJECT_TCP_PORT = tostring(try(var.helm_values.global.env["API_PROJECT_TCP_PORT"], 1805))
          PARAGON_ACTIONKIT_URL                 = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"
          CAPABILITY_BROKER_ACTIONKIT_URL       = "http://worker-actionkit:${var.microservices["worker-actionkit"].port}"
          BIFROST_URL                           = "http://agent-os-bifrost:8080"

          # The services consume Secrets through envFrom. Including the opaque
          # revision in the pod template makes secret-only Terraform changes
          # trigger a normal Helm rollout instead of waiting for a manual restart.
          AGENT_OS_SECRET_REVISION = var.secrets_revision
        }
      }
    }

    serviceAccount = {
      # Terraform creates this ServiceAccount and EKS Pod Identity binds it.
      create = false
    }

    secret = {
      # External Secrets owns agent-os-app/admin/broker on enterprise clusters.
      create = false
    }

    rbac = {
      create = true
    }

    prometheusRbac = {
      # Enterprise monitoring already owns its discovery permissions.
      enabled = false
    }

    kafkaAcls = {
      # AWS enterprise uses MSK SCRAM and the chart owns the ACL inventory.
      enabled = true
    }

    ingress = {
      # Agent OS is consumed from inside the Paragon cluster for now. This can
      # be enabled/configured from Terraform or .secure/values.yaml later.
      enabled = false
    }

    # The database roles are created by Helm hooks. They must run before the
    # Deployments become healthy, otherwise first install deadlocks waiting on
    # pods that cannot authenticate to Postgres yet.
    migration = {
      enabled = true
    }

    context-api = {
      enabled = true
    }

    context-ingest = {
      enabled = true
    }

    tools-api = {
      enabled = true
      env = {
        AGENT_OS_TOOL_SEARCH_ENABLED     = "true"
        AGENT_OS_TOOL_EXECUTE_ENABLED    = "true"
        AGENT_OS_EXEC_ALLOW_SIDE_EFFECTS = "true"
      }
    }

    tool-indexer = {
      enabled = true
    }

    capability-broker = {
      enabled             = true
      secretName          = "agent-os-capability-broker"
      includeGlobalSecret = false
    }

    index-maintainer = {
      enabled = true
      nodeSelector = {
        "useparagon.com/workload" = "agent-os-index"
      }
      tolerations = [{
        key      = "useparagon.com/workload"
        operator = "Equal"
        value    = "agent-os-index"
        effect   = "NoSchedule"
      }]
    }

    index-reader = {
      enabled = true
      nodeSelector = {
        "useparagon.com/workload" = "agent-os-index"
      }
      tolerations = [{
        key      = "useparagon.com/workload"
        operator = "Equal"
        value    = "agent-os-index"
        effect   = "NoSchedule"
      }]
    }

    index-writer = {
      enabled = true
      env = {
        # Bound glibc arenas so large Lance merge allocations return memory
        # instead of ratcheting the writer toward its container limit.
        MALLOC_ARENA_MAX = "4"
      }
    }

    extraction-service = {
      enabled = true
      nodeSelector = {
        "useparagon.com/workload" = "agent-os-extract"
      }
      tolerations = [{
        key      = "useparagon.com/workload"
        operator = "Equal"
        value    = "agent-os-extract"
        effect   = "NoSchedule"
      }]
    }

    # Bifrost is part of the Enterprise Agent OS release. VOYAGE_API_KEY remains
    # secret material and comes from the operator-managed vendor secret.
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

  # Helm deep-merges these in order. This gives us sane AWS defaults while
  # preserving two explicit override surfaces:
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
