output "agent_os" {
  value = var.agent_os_enabled && contains(keys(local.agent_os_valkey_instances), "cache") ? {
    host = (
      local.agent_os_valkey_instances["cache"].cluster_enabled
      ? aws_elasticache_replication_group.agent_os["cache"].configuration_endpoint_address
      : aws_elasticache_replication_group.agent_os["cache"].primary_endpoint_address
    )
    port     = aws_elasticache_replication_group.agent_os["cache"].port
    password = random_password.agent_os_valkey_auth["cache"].result
    ssl      = true
    cluster  = local.agent_os_valkey_instances["cache"].cluster_enabled
  } : null
  sensitive = true
}

output "elasticache" {
  value = var.elasticache_multiple_instances ? {
    for key, value in local.redis_instances :
    key => value.cluster == true ? {
      host    = aws_elasticache_replication_group.redis[key == "cache" ? 0 : 1].configuration_endpoint_address
      port    = 6379
      cluster = value.cluster
      } : {
      host    = aws_elasticache_cluster.redis[key].cache_nodes[0].address
      port    = aws_elasticache_cluster.redis[key].cache_nodes[0].port
      cluster = value.cluster
    }
    } : {
    cache = {
      host    = aws_elasticache_cluster.redis["cache"].cache_nodes[0].address
      port    = aws_elasticache_cluster.redis["cache"].cache_nodes[0].port
      cluster = false
    }
  }
  sensitive = true
}
