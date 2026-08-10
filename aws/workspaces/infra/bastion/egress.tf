# Private egress routing (NAT or Network Firewall) must exist before bastion instances bootstrap.
resource "terraform_data" "egress_ready" {
  input = var.egress_ready
}
