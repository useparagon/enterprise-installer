# Discover the ingress ALB via Resource Groups Tagging API (empty on greenfield before
# Helm creates the load balancer). Prefer the cluster tag; if that misses an existing
# ALB, scan load balancers by ARN name segment without a name-only aws_lb read (that
# fails greenfield plan). Do not depends_on Helm on aws_lb — that defers dns_name on
# chart bumps (PARA-26180). When the ALB still cannot be resolved, read an existing
# anchor CNAME so for_each does not drop and plan a mass destroy. Record-level
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
  # Prefer resource_tag_mapping_list; resource_arn_list is often null or a set and may be empty.
  ingress_alb_arns_tagged = var.enabled ? [
    for arn in distinct(concat(
      tolist(coalesce(data.aws_resourcegroupstaggingapi_resources.ingress_alb[0].resource_arn_list, toset([]))),
      [for m in coalesce(data.aws_resourcegroupstaggingapi_resources.ingress_alb[0].resource_tag_mapping_list, []) : m.resource_arn],
    )) :
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
    for arn in distinct(concat(
      tolist(coalesce(data.aws_resourcegroupstaggingapi_resources.ingress_alb_untagged[0].resource_arn_list, toset([]))),
      [for m in coalesce(data.aws_resourcegroupstaggingapi_resources.ingress_alb_untagged[0].resource_tag_mapping_list, []) : m.resource_arn],
    )) :
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
  ingress_alb_dns_name_live = local.ingress_alb_dns_target_ready ? data.aws_lb.ingress_dns_target[0].dns_name : null

  # Prefer api-sync (managed sync host); otherwise first public service lexicographically.
  route53_anchor_service_name = var.enabled && length(var.public_services) > 0 ? (
    contains(keys(var.public_services), "api-sync") ? "api-sync" : sort(keys(var.public_services))[0]
  ) : null
  route53_anchor_service = local.route53_anchor_service_name != null ? var.public_services[local.route53_anchor_service_name] : null

  route53_anchor_origin_name = local.route53_anchor_service == null ? "" : (
    var.path_based_routing_enabled && try(local.route53_anchor_service.path_prefix, "") != "" ?
    local.route53_anchor_service_name :
    trim(replace(
      replace(
        replace(local.route53_anchor_service.public_url, var.domain, ""),
        "https://",
        ""
      ),
      "http://",
      ""
    ), ".")
  )
  route53_anchor_fqdn = local.route53_anchor_service != null ? "${local.route53_anchor_origin_name}.${var.domain}." : ""
}

data "aws_route53_records" "cname_anchor" {
  count = var.enabled && local.ingress_alb_dns_name_live == null && local.route53_anchor_fqdn != "" ? 1 : 0

  zone_id    = var.route53_zone_id
  name_regex = replace(local.route53_anchor_fqdn, ".", "\\.")
}

locals {
  route53_cname_anchor_matches = try(flatten([
    for rs in data.aws_route53_records.cname_anchor[0].resource_record_sets : [
      for rr in rs.resource_records : rr.value
      if rs.type == "CNAME"
    ]
  ]), [])
  route53_cname_anchor_target = length(local.route53_cname_anchor_matches) > 0 ? trimsuffix(local.route53_cname_anchor_matches[0], ".") : null

  ingress_alb_dns_name = (
    local.ingress_alb_dns_name_live != null && local.ingress_alb_dns_name_live != ""
    ) ? local.ingress_alb_dns_name_live : (
    local.route53_cname_anchor_target != null && local.route53_cname_anchor_target != ""
  ) ? local.route53_cname_anchor_target : null

  manage_route53_cnames = var.enabled && local.ingress_alb_dns_name != null
}

resource "aws_route53_record" "microservice" {
  for_each = local.manage_route53_cnames ? var.public_services : {}

  zone_id = var.route53_zone_id
  # External proxy hostname belongs to the customer. Keep service-specific
  # Paragon origin CNAME for TLS/SNI while ALB routes by path, not Host.
  name = var.path_based_routing_enabled && try(each.value.path_prefix, "") != "" ? each.key : replace(
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
