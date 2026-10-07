# Discover the ingress ALB via Resource Groups Tagging API (empty on greenfield before
# Helm creates the load balancer). Prefer the cluster tag; if that misses an existing
# ALB, scan load balancers by ARN name segment without failing plan. Do not depends_on
# Helm on aws_lb — that defers dns_name on chart bumps (PARA-26180). Manage service
# CNAMEs only once an ALB ARN is resolved so greenfield plans succeed; record-level
# depends_on keeps apply order when CNAMEs first appear.
data "aws_resourcegroupstaggingapi_resources" "ingress_alb" {
  count = var.enabled ? 1 : 0

  resource_type_filters = ["elasticloadbalancing:loadbalancer"]
  tag_filter {
    key    = "elbv2.k8s.aws/cluster"
    values = [var.cluster_name]
  }
}

locals {
  ingress_alb_arns_tagged = var.enabled ? [
    for arn in coalesce(data.aws_resourcegroupstaggingapi_resources.ingress_alb[0].resource_arn_list, []) :
    arn
    if strcontains(arn, "loadbalancer/app/${var.workspace}/")
  ] : []
}

data "aws_resourcegroupstaggingapi_resources" "ingress_alb_untagged" {
  count = var.enabled && length(local.ingress_alb_arns_tagged) == 0 ? 1 : 0

  resource_type_filters = ["elasticloadbalancing:loadbalancer"]
}

locals {
  ingress_alb_arns_untagged = var.enabled && length(local.ingress_alb_arns_tagged) == 0 ? [
    for arn in coalesce(data.aws_resourcegroupstaggingapi_resources.ingress_alb_untagged[0].resource_arn_list, []) :
    arn
    if strcontains(arn, "loadbalancer/app/${var.workspace}/")
  ] : []

  ingress_alb_arns             = coalescelist(local.ingress_alb_arns_tagged, local.ingress_alb_arns_untagged)
  ingress_alb_dns_target_ready = length(local.ingress_alb_arns) > 0
}

data "aws_lb" "ingress_dns_target" {
  count = local.ingress_alb_dns_target_ready ? 1 : 0
  arn   = local.ingress_alb_arns[0]
}

locals {
  ingress_alb_dns_name = local.ingress_alb_dns_target_ready ? data.aws_lb.ingress_dns_target[0].dns_name : null
}

resource "aws_route53_record" "microservice" {
  for_each = var.enabled && local.ingress_alb_dns_target_ready ? var.public_services : {}

  zone_id = var.route53_zone_id
  name = replace(
    replace(
      replace(each.value.public_url, var.domain, ""),
      "https://",
      ""
    ),
    "http://",
    ""
  )
  type    = "CNAME"
  ttl     = var.record_ttl
  records = [local.ingress_alb_dns_name]

  depends_on = [
    var.release_ingress,
    var.release_paragon_logging,
    var.release_paragon_on_prem,
  ]
}
