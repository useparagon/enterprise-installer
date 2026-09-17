resource "aws_security_group" "elasticache" {
  name_prefix = "${var.workspace}-elasticache"
  description = "Security access rules for Elasticache."
  vpc_id      = var.vpc.id

  ingress {
    description = "Allow inbound traffic from services in the public subnet on port 6379."
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.public_subnet.*.cidr_block
  }

  ingress {
    description = "Allow inbound traffic from services in the private subnet on port 6379."
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.private_subnet.*.cidr_block
  }

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-elasticache"
  }
}

# Agent OS Valkey accepts traffic only from private workload subnets.
resource "aws_security_group" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name_prefix = "${var.workspace}-agent-os-valkey"
  description = "Security access rules for Agent OS Valkey."
  vpc_id      = var.vpc.id

  ingress {
    description = "Allow Agent OS workloads on port 6379."
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.private_subnet[*].cidr_block
  }

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-agent-os-valkey"
  }
}
