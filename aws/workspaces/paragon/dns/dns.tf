# Resolve the ingress ALB without a name-only aws_lb read at plan time (that fails
# greenfield before Helm creates the load balancer). Tagging API returns an empty
# list (or null from the provider) when no ALB exists yet; do not depends_on Helm on the aws_lb data source —
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
}

data "aws_lb" "ingress_dns_target" {
  count = length(local.ingress_alb_arns) > 0 ? 1 : 0
  arn   = local.ingress_alb_arns[0]
}

locals {
  ingress_alb_dns_name_live = try(data.aws_lb.ingress_dns_target[0].dns_name, null)

  # Prefer api-sync (managed sync host); otherwise first public service lexicographically.
  route53_anchor_service = var.enabled && length(var.public_services) > 0 ? (
    contains(keys(var.public_services), "api-sync") ? var.public_services["api-sync"] : var.public_services[sort(keys(var.public_services))[0]]
  ) : null

  route53_anchor_fqdn = local.route53_anchor_service != null ? "${trim(replace(
    replace(
      replace(local.route53_anchor_service.public_url, var.domain, ""),
      "https://",
      ""
    ),
    "http://",
    ""
  ), ".")}.${var.domain}." : ""
}

# When tagging misses the ALB but service CNAMEs already exist (brownfield), read the
# anchor record target so plan does not drop for_each and schedule a mass destroy.
# Empty result on greenfield (no record yet) is normal — coalesce stays null until the ALB is visible.
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
  # coalesce() errors when every argument is null or ""; greenfield has no ALB or anchor yet.
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
