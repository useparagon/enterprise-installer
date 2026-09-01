locals {
  # Every service the shared ALB can target, not only the publicly routed ones:
  # the microservice charts enable ingress by default, so internal workers get
  # target groups too.
  alb_target_ports = [
    for service in values(merge(var.microservices, var.public_monitors)) : service.port
  ]

  # The controller typically attaches both a frontend SG and a shared backend SG
  # to the ALB. Authorize every ALB SG as a source so plan does not depend on a
  # single-element list and health checks still match whichever SG the ENI uses.
  alb_target_safeguard_pairs = {
    for pair in setproduct(toset(var.worker_security_group_ids), toset(data.aws_lb.load_balancer.security_groups)) :
    "${pair[0]}:${pair[1]}" => {
      worker_security_group_id = pair[0]
      alb_security_group_id    = pair[1]
    }
  }
}

# The controller authorizes ALB-to-pod access as a single coalesced port range and
# replaces it with a revoke followed by an authorize. If it is interrupted between
# the two, targets in the dropped range become unreachable while pods stay healthy.
# Holding the same range here keeps every target port authorized through that gap,
# and one range rule per SG pair avoids consuming a per-port rule out of the
# security group quota.
resource "aws_vpc_security_group_ingress_rule" "alb_target_safeguard" {
  for_each = local.alb_target_safeguard_pairs

  security_group_id            = each.value.worker_security_group_id
  referenced_security_group_id = each.value.alb_security_group_id
  description                  = "Paragon ALB target safeguard"
  ip_protocol                  = "tcp"
  from_port                    = min(local.alb_target_ports...)
  to_port                      = max(local.alb_target_ports...)
}
