output "namespace_name" {
  description = "The name of the Event Hubs namespace"
  value       = azurerm_eventhub_namespace.kafka.name
}

output "bootstrap_servers" {
  description = "The Kafka bootstrap servers connection string (for Kafka protocol)"
  value       = "${azurerm_eventhub_namespace.kafka.name}.servicebus.windows.net:9093"
}

output "bootstrap_servers_private" {
  description = "The private DNS name for Kafka bootstrap servers"
  value       = "${azurerm_eventhub_namespace.kafka.name}.privatelink.servicebus.windows.net:9093"
}

output "kafka_credentials" {
  description = "Kafka credentials (Event Hubs uses SASL PLAIN authentication with connection string)"
  value = {
    username  = "$ConnectionString"
    password  = azurerm_eventhub_namespace_authorization_rule.kafka.primary_connection_string
    mechanism = "PLAIN" # Event Hubs uses SASL PLAIN authentication
  }
  sensitive = true
}

output "tls_enabled" {
  description = "TLS is required for Event Hubs Kafka (port 9093)."
  value       = true
}

output "agent_os_kafka_credentials" {
  description = "Read-only namespace Event Hubs credentials for the Agent OS Kafka consumer."
  value = var.agent_os_enabled ? {
    username  = "$ConnectionString"
    password  = azurerm_eventhub_namespace_authorization_rule.agent_os[0].primary_connection_string
    mechanism = "PLAIN"
  } : null
  sensitive = true
}

output "agent_os_dlt_kafka_credentials" {
  description = "Entity-scoped send-only Event Hubs credentials for the Agent OS status DLT."
  value = var.agent_os_enabled ? {
    username  = "$ConnectionString"
    password  = azurerm_eventhub_authorization_rule.agent_os_dlt_writer[0].primary_connection_string
    mechanism = "PLAIN"
  } : null
  sensitive = true
}

