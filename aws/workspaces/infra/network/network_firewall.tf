module "network_firewall" {
  count  = var.network_firewall.enabled ? 1 : 0
  source = "../network_firewall"

  workspace = var.workspace
  vpc_id    = aws_vpc.app.id
  vpc_cidr  = var.vpc_cidr
  az_count  = var.az_count

  availability_zones      = data.aws_availability_zones.available.names
  firewall_subnet_ids     = aws_subnet.firewall[*].id
  private_route_table_ids = aws_route_table.private[*].id
  main_route_table_id     = aws_vpc.app.main_route_table_id
  nat_gateway_ids         = aws_nat_gateway.gw[*].id
  private_subnet_cidrs    = aws_subnet.private[*].cidr_block
  logs_bucket_name        = var.logs_bucket_name

  network_firewall = var.network_firewall
}
