# Grafana CloudWatch access via EKS Pod Identity (no long-lived IAM access keys).
data "aws_iam_policy_document" "grafana_assume" {
  statement {
    sid = "PodIdentity"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  name               = "${var.workspace}-iam-grafana"
  path               = "/env/"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json

  tags = {
    Name = "${var.workspace}-iam-grafana"
  }
}

resource "aws_iam_role_policy" "grafana_ro" {
  name = "${var.workspace}-iam-grafana-policy"
  role = aws_iam_role.grafana.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudwatch:DescribeInsightRules",
          "cloudwatch:GetDashboard",
          "cloudwatch:GetInsightRuleReport",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAnomalyDetectors",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:ListMetricStreams",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:ListDashboards",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricStream",
          "cloudwatch:GetMetricWidgetImage",
          "logs:DescribeLogGroups",
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "grafana" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "grafana"
  role_arn        = aws_iam_role.grafana.arn
}

resource "random_string" "grafana_admin_email_prefix" {
  count = var.grafana_admin_email == null && var.grafana_admin_password == null ? 1 : 0

  length  = 16
  special = false
  numeric = false
  lower   = true
  upper   = false
}

resource "random_password" "grafana_admin_password" {
  count = var.grafana_admin_email == null && var.grafana_admin_password == null ? 1 : 0

  length      = 16
  min_upper   = 2
  min_lower   = 2
  min_special = 0
  numeric     = true
  special     = false
  lower       = true
  upper       = true
}
