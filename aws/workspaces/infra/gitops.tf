# GitOps cluster add-ons: External Secrets Operator, AWS Load Balancer Controller,
# and external-dns. Wired into eks_blueprints_addons from modules.tf.

# ---------------------------------------------------------------------------
# External Secrets Operator (ESO)
# ---------------------------------------------------------------------------
# ESO is installed and IRSA-bound by eks-blueprints-addons (enable_external_secrets).
# The addon creates the IAM role, policy (scoped to the ARNs below), service account,
# and the IRSA annotation. We only supply scoped Secrets Manager ARNs and chart overrides.

locals {
  gitops_eso_namespace = "external-secrets"

  # Secrets the operator may read. Prefer the concrete secret ARNs; fall back to the
  # per-workspace prefix wildcard when the secrets module has not created them yet.
  gitops_eso_secret_arns = var.argocd_enabled && local.argocd_secrets_ready ? module.secrets[0].secret_arns : [
    "arn:aws:secretsmanager:${var.aws_region}:*:secret:paragon/${local.workspace}/*",
  ]

  gitops_external_secrets = merge(
    {
      name             = "external-secrets"
      namespace        = local.gitops_eso_namespace
      create_namespace = true
      chart_version    = var.eso_chart_version
      skip_crds        = false
      wait             = true
      wait_for_jobs    = true
      timeout          = 600
      values = [yamlencode({
        installCRDs = true
        crds = {
          createClusterSecretStore    = true
          createClusterExternalSecret = true
          createClusterGenerator      = true
          createPushSecret            = true
        }
      })]
    },
    var.eso_addon_overrides
  )

  # ---------------------------------------------------------------------------
  # Ingress (AWS Load Balancer Controller + external-dns)
  # ---------------------------------------------------------------------------
  # Legacy paragon workspace installed these via helm/helm.tf; the argocd_enabled
  # infra path must provide the same controllers so Ingress resources provision ALBs
  # and Route 53 records.

  # Brownfield: the legacy paragon Helm "ingress" release left a cluster-scoped
  # IngressClass "alb" without ownership metadata for the new LBC release. When that
  # IngressClass already exists, set createIngressClassResource=false to avoid a
  # conflict. Driven by an explicit var (set per stack) rather than a plan-time cluster
  # read, which would block the entire plan whenever the API is briefly unreachable.
  gitops_alb_ingress_class_exists = var.argocd_enabled && var.gitops_alb_ingressclass_exists

  gitops_aws_load_balancer_controller = merge(
    {
      name      = "aws-load-balancer-controller"
      namespace = "kube-system"
      # upgrades require kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
      chart_version    = "3.3.0"
      create_namespace = false
      wait             = true
      wait_for_jobs    = true
      timeout          = 600
    },
    local.gitops_alb_ingress_class_exists ? {
      values = [yamlencode({
        createIngressClassResource = false
      })]
    } : {}
  )

  gitops_external_dns = {
    name             = "external-dns"
    namespace        = "external-dns"
    create_namespace = true
    wait             = true
    wait_for_jobs    = true
    timeout          = 600
    values = [yamlencode({
      provider      = "aws"
      policy        = "sync"
      txtOwnerId    = local.workspace
      domainFilters = [local.paragon_domain_trimmed]
      sources       = ["ingress", "service"]
    })]
  }
}

# Wait for ESO CRDs after the Blueprints Helm release completes. The sleep re-runs when
# the Helm revision changes so retries after a failed ClusterSecretStore apply still wait.
resource "time_sleep" "gitops_eso_crds" {
  count = var.argocd_enabled ? 1 : 0

  create_duration = "120s"

  triggers = {
    eso_revision      = try(tostring(module.eks_blueprints_addons.external_secrets.revision), "0")
    eso_chart_release = try(module.eks_blueprints_addons.external_secrets.version, "")
    eso_chart_version = var.eso_chart_version
  }

  depends_on = [module.eks_blueprints_addons]
}
