data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ec2_instance_type" "node" {
  for_each = local.node_instance_types_all

  instance_type = each.key
}
