resource "aws_route_table" "firewall" {
  count  = var.az_count
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.workspace}-firewall-route-table-${substr(var.availability_zones[count.index], length(var.availability_zones[count.index]) - 2, 2)}"
  }
}

resource "aws_route_table_association" "firewall" {
  count          = var.az_count
  subnet_id      = var.firewall_subnet_ids[count.index]
  route_table_id = aws_route_table.firewall[count.index].id
}

# Firewall subnet egress: inspected traffic exits via NAT in the same AZ.
resource "aws_route" "firewall_egress" {
  count                  = var.az_count
  route_table_id         = aws_route_table.firewall[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids[count.index]
}

# Private subnet egress: send internet-bound traffic to the firewall endpoint in the same AZ.
resource "aws_route" "private_egress" {
  count                  = var.az_count
  route_table_id         = var.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.firewall_endpoint_ids[count.index]

  depends_on = [aws_networkfirewall_firewall.this]
}

# Symmetric return: NAT return traffic is steered back through the firewall endpoint.
resource "aws_route" "symmetric_return" {
  count                  = var.az_count
  route_table_id         = var.main_route_table_id
  destination_cidr_block = var.private_subnet_cidrs[count.index]
  vpc_endpoint_id        = local.firewall_endpoint_ids[count.index]

  depends_on = [aws_networkfirewall_firewall.this]
}
