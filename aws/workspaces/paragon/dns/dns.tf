# Discover the ingress ALB via Resource Groups Tagging API first (empty on greenfield
# before Helm creates the load balancer). When tagging misses an existing ALB (tags,
# eventual consistency, ARN shape), fall back to a name lookup without Helm depends_on
# so dns_name stays plan-stable on chart bumps (PARA-26180). Service CNAME for_each
# keys always track public_services so a tagging miss cannot plan destroys. Record-level
# depends_on keeps apply order when the ALB first becomes visible.
data "aws_resourcegroupstaggingapi_resources" "ingress_alb" {
  count = var.enabled ? 1 : 0

  resource_type_filters = ["elasticloadbalancing:loadbalancer"]
  tag_filter {
    key    = "elbv2.k8s.aws/cluster"
    values = [var.cluster_name]
  }
}

locals {
  ingress_alb_arns = var.enabled ? [
    for arn in coalesce(data.aws_resourcegroupstaggingapi_resources.ingress_alb[0].resource_arn_list, []) :
    arn
    if strcontains(arn, "loadbalancer/app/${var.workspace}/")
  ] : []
  ingress_alb_dns_target_ready = length(local.ingress_alb_arns) > 0
}

data "aws_lb" "ingress_dns_target_by_arn" {
  count = local.ingress_alb_dns_target_ready ? 1 : 0
  arn   = local.ingress_alb_arns[0]
}

data "aws_lb" "ingress_dns_target_by_name" {
  count = var.enabled && !local.ingress_alb_dns_target_ready ? 1 : 0
  name  = var.workspace
}

locals {
  ingress_alb_dns_name = local.ingress_alb_dns_target_ready ? data.aws_lb.ingress_dns_target_by_arn[0].dns_name : data.aws_lb.ingress_dns_target_by_name[0].dns_name
}

resource "aws_route53_record" "microservice" {
  for_each = var.enabled ? var.public_services : {}

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
