locals {
  agent_os_public_url = try(var.helm_values.global.env["AGENT_OS_PUBLIC_URL"], format("https://agentos.%s", var.domain))
  agent_os_host       = replace(replace(local.agent_os_public_url, "https://", ""), "http://", "")
  agent_os_port       = try(tonumber(var.helm_values.global.env["AGENT_OS_PORT"]), 3000)

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

        services = {
          context-api = local.agent_os_port
        }

        env = {
          HOST_ENV                              = "AWS_K8"
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

  # Same shared ALB group as Managed Sync (workspace), but keep a distinct
  # Ingress object name — managed-sync already owns metadata.name = workspace.
  agent_os_aws_ingress_values = yamlencode({
    ingress = {
      annotations = merge(
        {
          "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "false"
          "alb.ingress.kubernetes.io/group.name"                          = var.workspace
          "alb.ingress.kubernetes.io/load-balancer-name"                  = var.workspace
        },
        var.waf_web_acl_arn != "" ? {
          "alb.ingress.kubernetes.io/wafv2-acl-arn" = var.waf_web_acl_arn
        } : {}
      )
    }
  })
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

  values = [
    yamlencode(local.agent_os_aws_values),
    local.agent_os_aws_ingress_values,
    yamlencode(var.agent_os_helm_values),
    yamlencode(var.agent_os_file_values),
  ]

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.host"
    value = local.agent_os_host
  }

  set {
    name  = "ingress.certificate"
    value = var.certificate
  }

  # Chart metadata.name; ALB group is workspace via ingress.annotations above.
  set {
    name  = "ingress.loadBalancerName"
    value = "agent-os"
  }

  set {
    name  = "ingress.scheme"
    value = var.ingress_scheme
  }

  set {
    name  = "ingress.listenPorts[0].HTTP"
    value = "80"
  }

  set {
    name  = "ingress.listenPorts[1].HTTPS"
    value = "443"
  }

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
