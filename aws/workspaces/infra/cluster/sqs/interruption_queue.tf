locals {
  queue_name = var.create ? coalesce(var.queue_name, "Karpenter-${var.cluster_name}") : ""

  interruption_events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      pattern = jsonencode({
        source        = ["aws.health"]
        "detail-type" = ["AWS Health Event"]
      })
    }
    spot_interrupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      pattern = jsonencode({
        source        = ["aws.ec2"]
        "detail-type" = ["EC2 Spot Instance Interruption Warning"]
      })
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      pattern = jsonencode({
        source        = ["aws.ec2"]
        "detail-type" = ["EC2 Instance Rebalance Recommendation"]
      })
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      pattern = jsonencode({
        source        = ["aws.ec2"]
        "detail-type" = ["EC2 Instance State-change Notification"]
      })
    }
    capacity_reservation_interruption = {
      name        = "CRInterruption"
      description = "Karpenter interrupt - EC2 capacity reservation instance interruption warning"
      pattern = jsonencode({
        source        = ["aws.ec2"]
        "detail-type" = ["EC2 Capacity Reservation Instance Interruption Warning"]
      })
    }
  }
}

resource "aws_sqs_queue" "interruption" {
  count = var.create ? 1 : 0

  name                      = local.queue_name
  message_retention_seconds = var.message_retention_seconds

  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = 300

  tags = var.tags
}

data "aws_iam_policy_document" "queue" {
  count = var.create ? 1 : 0

  statement {
    sid       = "SqsWrite"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }

  statement {
    sid    = "DenyHTTP"
    effect = "Deny"
    actions = [
      "sqs:*"
    ]
    resources = [aws_sqs_queue.interruption[0].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "interruption" {
  count = var.create ? 1 : 0

  queue_url = aws_sqs_queue.interruption[0].url
  policy    = data.aws_iam_policy_document.queue[0].json

  depends_on = [aws_sqs_queue.interruption]
}

resource "aws_cloudwatch_event_rule" "interruption" {
  for_each = var.create ? local.interruption_events : {}

  name_prefix   = "${var.rule_name_prefix}${each.value.name}-"
  description   = each.value.description
  event_pattern = each.value.pattern

  tags = merge(
    { ClusterName = var.cluster_name },
    var.tags,
  )
}

resource "aws_cloudwatch_event_target" "interruption" {
  for_each = var.create ? local.interruption_events : {}

  rule      = aws_cloudwatch_event_rule.interruption[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.interruption[0].arn

  depends_on = [aws_sqs_queue_policy.interruption]
}
