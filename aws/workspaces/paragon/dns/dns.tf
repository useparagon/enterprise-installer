# Apply after module.helm at the call site so greenfield stacks create the ALB
# before CNAMEs. Do not depends_on Helm on this data source — that defers dns_name
# to apply time on every chart bump (PARA-26180).
data "aws_lb" "ingress_dns_target" {
  count = var.enabled ? 1 : 0
  name  = var.workspace

  lifecycle {
    postcondition {
      condition     = self.dns_name != ""
      error_message = "Application load balancer \"${var.workspace}\" was not found. Ensure ingress Helm releases have created the ALB before service Route 53 records apply."
    }
  }
}

resource "aws_route53_record" "microservice" {
  for_each = var.enabled ? merge(var.public_microservices, var.public_monitors) : {}

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
}
