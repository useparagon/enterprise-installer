output "agent_os" {
  value = var.agent_os_enabled && contains(keys(local.agent_os_valkey_instances), "cache") ? {
    host    = try(local.agent_os_valkey_endpoints["cache"].ip_address, null)
    port    = try(local.agent_os_valkey_endpoints["cache"].port, null)
    ssl     = true
    cluster = local.agent_os_valkey_instances["cache"].cluster_enabled
    ca_certificate = join("\n", flatten([
      for chain in google_memorystore_instance.agent_os["cache"].managed_server_ca[0].ca_certs :
      chain.certificates
    ]))
  } : null
  sensitive = true

  precondition {
    condition = (
      !var.agent_os_enabled ||
      !contains(keys(local.agent_os_valkey_instances), "cache") ||
      local.agent_os_valkey_endpoints["cache"] != null
    )
    error_message = "Agent OS Valkey did not return the required primary/discovery PSC endpoint."
  }
}


output "redis" {
  value = var.multi_redis ? {
    for key, value in local.redis_instances :
    key => {
      host              = google_redis_instance.redis[key].host
      port              = google_redis_instance.redis[key].port
      password          = google_redis_instance.redis[key].auth_string
      ssl               = google_redis_instance.redis[key].transit_encryption_mode == "SERVER_AUTHENTICATION"
      connection_string = ":${google_redis_instance.redis[key].auth_string}@${google_redis_instance.redis[key].host}:${google_redis_instance.redis[key].port}"
      # CA certificate for TLS connections (first certificate in the array)
      ca_certificate = google_redis_instance.redis[key].transit_encryption_mode == "SERVER_AUTHENTICATION" && length(google_redis_instance.redis[key].server_ca_certs) > 0 ? google_redis_instance.redis[key].server_ca_certs[0].cert : null
    }
    } : {
    cache = {
      host              = google_redis_instance.redis["cache"].host
      port              = google_redis_instance.redis["cache"].port
      password          = google_redis_instance.redis["cache"].auth_string
      ssl               = google_redis_instance.redis["cache"].transit_encryption_mode == "SERVER_AUTHENTICATION"
      connection_string = ":${google_redis_instance.redis["cache"].auth_string}@${google_redis_instance.redis["cache"].host}:${google_redis_instance.redis["cache"].port}"
      # CA certificate for TLS connections (first certificate in the array)
      ca_certificate = google_redis_instance.redis["cache"].transit_encryption_mode == "SERVER_AUTHENTICATION" && length(google_redis_instance.redis["cache"].server_ca_certs) > 0 ? google_redis_instance.redis["cache"].server_ca_certs[0].cert : null
    }
  }
  sensitive = true
}
