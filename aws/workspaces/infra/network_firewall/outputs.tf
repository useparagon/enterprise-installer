output "firewall_arn" {
  description = "Network Firewall ARN."
  value       = aws_networkfirewall_firewall.this.arn
}

output "routing_ready" {
  description = "Signals firewall endpoints and egress/return routes are configured."
  value = join(",", concat(
    [aws_networkfirewall_firewall.this.arn],
    aws_route.private_egress[*].id,
    aws_route.symmetric_return[*].id,
    aws_route.firewall_egress[*].id,
  ))
}
