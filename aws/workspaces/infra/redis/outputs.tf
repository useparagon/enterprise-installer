locals {
  redis_tls_cluster = var.elasticache_transit_encryption_enabled

  redis_cluster_endpoint = {
    for key, idx in local.replication_group_index :
    key => {
      host = aws_elasticache_replication_group.redis[idx].configuration_endpoint_address
      port = aws_elasticache_replication_group.redis[idx].port
    }
  }

  redis_cluster_auth_token = var.elasticache_transit_encryption_enabled ? {
    for key, idx in local.replication_group_index :
    key => random_password.redis_auth_token[idx].result
  } : {}
}

output "elasticache" {
  value = var.elasticache_multiple_instances ? {
    for key, value in local.redis_instances :
    key => value.cluster ? {
      host     = local.redis_cluster_endpoint[key].host
      port     = local.redis_cluster_endpoint[key].port
      cluster  = value.cluster
      ssl      = local.redis_tls_cluster
      password = try(local.redis_cluster_auth_token[key], null)
      # ElastiCache uses Amazon-issued certs; clients use --tls with the system trust store.
      ca_certificate = null
      connection_string = local.redis_tls_cluster ? format(
        ":%s@%s:%s",
        urlencode(try(local.redis_cluster_auth_token[key], "")),
        local.redis_cluster_endpoint[key].host,
        local.redis_cluster_endpoint[key].port,
      ) : format("%s:%s", local.redis_cluster_endpoint[key].host, local.redis_cluster_endpoint[key].port)
      } : {
      host     = aws_elasticache_cluster.redis[key].cache_nodes[0].address
      port     = aws_elasticache_cluster.redis[key].cache_nodes[0].port
      cluster  = value.cluster
      ssl      = false
      password = null
      ca_certificate = null
      connection_string = format(
        "%s:%s",
        aws_elasticache_cluster.redis[key].cache_nodes[0].address,
        aws_elasticache_cluster.redis[key].cache_nodes[0].port,
      )
    }
    } : {
    cache = {
      host     = aws_elasticache_cluster.redis["cache"].cache_nodes[0].address
      port     = aws_elasticache_cluster.redis["cache"].cache_nodes[0].port
      cluster  = false
      ssl      = false
      password = null
      ca_certificate = null
      connection_string = format(
        "%s:%s",
        aws_elasticache_cluster.redis["cache"].cache_nodes[0].address,
        aws_elasticache_cluster.redis["cache"].cache_nodes[0].port,
      )
    }
  }
  sensitive = true
}
