output "vpc" {
  value = aws_vpc.app
}

output "public_subnet" {
  value = aws_subnet.public
}

output "private_subnet" {
  value = aws_subnet.private
}

output "availability_zones" {
  value = data.aws_availability_zones.available
}

output "gateway_ip" {
  value = aws_eip.gw.*.public_ip
}

output "firewall_subnet" {
  value = aws_subnet.firewall
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "main_route_table_id" {
  value = aws_vpc.app.main_route_table_id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.gw[*].id
}

output "private_subnet_cidrs" {
  value = aws_subnet.private[*].cidr_block
}

output "egress_ready" {
  description = "Signals private egress routing is configured (firewall ARN when NFW is enabled, otherwise VPC ID)."
  value       = var.network_firewall.enabled ? module.network_firewall[0].firewall_arn : aws_vpc.app.id
}
