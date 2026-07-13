resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.workspace}-network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.vpc_id

  dynamic "subnet_mapping" {
    for_each = range(var.az_count)
    content {
      subnet_id = var.firewall_subnet_ids[subnet_mapping.key]
    }
  }

  tags = {
    Name = "${var.workspace}-network-firewall"
  }
}

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination      = local.log_destination
      log_destination_type = "S3"
      log_type             = "FLOW"
    }

    log_destination_config {
      log_destination      = local.log_destination
      log_destination_type = "S3"
      log_type             = "ALERT"
    }
  }
}
