locals {
  cas_namespace = "kube-system"
  cas_sa_name   = "${var.workspace}-cluster-autoscaler"
}

data "aws_iam_policy_document" "cas_assume" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.cas_namespace}:${local.cas_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  name               = "${var.workspace}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cas_assume[0].json

  tags = {
    Name = "${var.workspace}-cluster-autoscaler"
  }
}

data "aws_iam_policy_document" "cas_permissions" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  name   = "cluster-autoscaler"
  role   = aws_iam_role.cluster_autoscaler[0].id
  policy = data.aws_iam_policy_document.cas_permissions[0].json
}

resource "kubectl_manifest" "cluster_autoscaler_application" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-cluster-autoscaler"
      namespace = var.argocd_namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io",
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://kubernetes.github.io/autoscaler"
        chart          = "cluster-autoscaler"
        targetRevision = "9.46.0"
        helm = {
          values = yamlencode({
            autoDiscovery = {
              clusterName = var.cluster_name
            }
            awsRegion = var.aws_region
            rbac = {
              serviceAccount = {
                name = local.cas_sa_name
                annotations = {
                  "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler[0].arn
                }
              }
            }
            extraArgs = {
              skip-nodes-with-local-storage = false
              skip-nodes-with-system-pods   = false
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = local.cas_namespace
      }
      syncPolicy = local.sync_policy
    }
  })

  depends_on = [time_sleep.eso_crds, helm_release.argocd]
}
