locals {
  vpc_prefix_len       = tonumber(split("/", var.vpc_cidr)[1])
  firewall_parent_cidr = cidrsubnet(var.vpc_cidr, var.vpc_cidr_newbits, 0)
  firewall_subnet_bits = 28 - (local.vpc_prefix_len + var.vpc_cidr_newbits)
  max_firewall_subnets = local.firewall_subnet_bits >= 0 ? pow(2, local.firewall_subnet_bits) : 0
}

check "firewall_subnet_capacity" {
  assert {
    condition = (
      !var.network_firewall_enabled ||
      (local.firewall_subnet_bits >= 0 && var.az_count <= local.max_firewall_subnets)
    )
    error_message = "VPC CIDR plan does not leave enough /28 firewall subnets for az_count; adjust vpc_cidr or vpc_cidr_newbits."
  }
}
