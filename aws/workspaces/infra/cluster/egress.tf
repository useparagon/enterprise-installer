# Private egress routing (NAT or Network Firewall) must exist before EKS nodes bootstrap.
resource "terraform_data" "egress_ready" {
  input = var.egress_ready
}
