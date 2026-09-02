locals {
  # Every service the shared ALB can target, not only the publicly routed ones:
  # the microservice charts enable ingress by default, so internal workers get
  # target groups too.
  alb_target_ports = [
    for service in values(merge(var.microservices, var.public_monitors)) : service.port
  ]
}

# Terraform-owned backend SG: for_each keys stay plan-known (worker SG IDs plus
# this resource), unlike data.aws_lb.security_groups which is deferred whenever
# the Helm releases this module depends_on change. The controller attaches this
# SG to the ALB via --backend-security-group so ENI traffic matches the rules.
# Auto-generated frontend SGs ignore manage-backend-security-group-rules, so the
# controller still authorizes worker access from this SG. Helm sets
# disableRestrictedSecurityGroupRules so that permission is 0-65535, not this
# coalesced target-port range (AWS merges identical protocol/port/source rules).
resource "aws_security_group" "alb_backend" {
  name        = "${var.workspace}-alb-backend"
  description = "Source SG for Paragon ALB-to-worker target-port safeguards"
  vpc_id      = var.vpc_id

  tags = {
    Name                    = "${var.workspace}-alb-backend"
    Workspace               = var.workspace
    "elbv2.k8s.aws/cluster" = var.cluster_name
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_backend" {
  security_group_id = aws_security_group.alb_backend.id
  description       = "ALB egress to targets"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Durable ALB-to-pod access for every target port. One coalesced range avoids
# consuming a per-port rule out of the security group quota. Distinct from the
# controller's 0-65535 backend rule so neither revoke nor DuplicatePermission.
resource "aws_vpc_security_group_ingress_rule" "alb_target_safeguard" {
  for_each = toset(var.worker_security_group_ids)

  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.alb_backend.id
  description                  = "Paragon ALB target safeguard"
  ip_protocol                  = "tcp"
  from_port                    = min(local.alb_target_ports...)
  to_port                      = max(local.alb_target_ports...)
}
