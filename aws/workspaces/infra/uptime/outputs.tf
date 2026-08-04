output "webhook" {
  description = "BetterStack Grafana integration webhook URL."
  value       = local.enabled ? betteruptime_grafana_integration.webhook[0].webhook_url : ""
  sensitive   = true
}
