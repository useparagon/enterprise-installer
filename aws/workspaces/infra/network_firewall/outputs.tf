output "firewall_arn" {
  description = "Network Firewall ARN. Signals routing and endpoints are ready."
  value       = aws_networkfirewall_firewall.this.arn
}
