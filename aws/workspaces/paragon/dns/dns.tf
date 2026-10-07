# Resolve the ingress ALB without a name-only aws_lb read at plan time (that fails
# greenfield before Helm creates the load balancer). Tagging API returns an empty
# empty list (or null from the provider) when no ALB exists yet; do not depends_on Helm on the aws_lb data source —
# that defers dns_name on chart bumps (PARA-26180). Record-level depends_on keeps
# apply order when CNAMEs are created on the first plan where the ALB is visible.
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

data "aws_lb" "ingress_dns_target" {
  count = local.ingress_alb_dns_target_ready ? 1 : 0
  arn   = local.ingress_alb_arns[0]
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
  records = [data.aws_lb.ingress_dns_target[0].dns_name]

  depends_on = [
    var.release_ingress,
    var.release_paragon_logging,
    var.release_paragon_on_prem,
  ]
}
