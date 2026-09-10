# not every instance type is available within each AZ so filter AZs to just those with desired node type
data "aws_ec2_instance_type_offerings" "cache_filter" {
  filter {
    name   = "instance-type"
    values = [substr(local.redis_instances.cache.size, 6, -1)] # strip "cache." to filter
  }
  filter {
    name   = "location"
    values = var.private_subnet.*.availability_zone
  }
  location_type = "availability-zone"
}

# then filter subnets to just those filtered AZs
locals {
  cache_subnet_ids = [for each in var.private_subnet : each.id if contains(data.aws_ec2_instance_type_offerings.cache_filter.locations, each.availability_zone)]
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.workspace}-elasticache-subnet"
  subnet_ids = local.cache_subnet_ids
}

resource "aws_elasticache_parameter_group" "redis" {
  for_each = toset(["cluster", "standalone"])

  name   = "${var.workspace}-redis-${each.key}${substr(local.redis_version, 0, 1)}"
  family = "redis${local.redis_version}"

  # when max memory is reached, the eviction policy is to remove the least-recently-used keys
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  # how often, in seconds, clients are pinged to ensure they're still connected
  parameter {
    name  = "tcp-keepalive"
    value = "30"
  }

  # number of seconds nodes wait before disconnecting idle clients
  parameter {
    name  = "timeout"
    value = "120"
  }

  # whether or not cluster is enabled
  parameter {
    name  = "cluster-enabled"
    value = each.key == "cluster" ? "yes" : "no"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-redis${local.redis_version}-${each.key}"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  count = var.elasticache_multiple_instances ? (var.managed_sync_enabled ? 2 : 1) : 0

  replication_group_id = "${var.workspace}-redis-${count.index == 0 ? "cache" : "sync"}"
  description          = "Redis cluster for caching & workflows."
  apply_immediately    = true
  node_type            = local.redis_instances.cache.size
  engine_version       = local.redis_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis["cluster"].name

  snapshot_retention_limit = 5
  snapshot_window          = "12:00-13:00"
  maintenance_window       = "tue:16:00-tue:17:00"

  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.elasticache.id]
  multi_az_enabled           = var.elasticache_multi_az
  automatic_failover_enabled = true
  num_node_groups            = 1
  replicas_per_node_group    = var.elasticache_multi_az ? 1 : 0

  # don't let terraform undo any autoscaling
  lifecycle {
    ignore_changes = [num_node_groups]
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name    = "${var.workspace}-redis-${count.index == 0 ? "cache" : "sync"}"
    Cluster = "true"
  }
}

resource "aws_elasticache_cluster" "redis" {
  for_each = local.redis_instances_standalone

  cluster_id           = var.elasticache_multiple_instances ? "${var.workspace}-redis-${each.key}" : "${var.workspace}-redis"
  engine               = "redis"
  node_type            = each.value.size
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis["standalone"].name
  engine_version       = local.redis_version
  port                 = 6379
  apply_immediately    = true

  snapshot_retention_limit = 5
  snapshot_window          = "12:00-13:00"
  maintenance_window       = "tue:16:00-tue:17:00"
  subnet_group_name        = aws_elasticache_subnet_group.main.name
  security_group_ids       = [aws_security_group.elasticache.id]

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name    = "${var.workspace}-redis-${each.key}"
    Cluster = "false"
  }
}

resource "aws_cloudwatch_log_group" "redis" {
  name_prefix       = "${var.workspace}-redis"
  retention_in_days = 365
}

resource "aws_appautoscaling_target" "cache" {
  for_each = local.cache_autoscaling_targets

  resource_id        = each.value.resource_id
  service_namespace  = "elasticache"
  scalable_dimension = "elasticache:replication-group:NodeGroups"
  min_capacity       = 1
  max_capacity       = 10
}

resource "aws_appautoscaling_policy" "cache_memory" {
  for_each = local.cache_autoscaling_targets

  resource_id        = aws_appautoscaling_target.cache[each.key].resource_id
  service_namespace  = aws_appautoscaling_target.cache[each.key].service_namespace
  scalable_dimension = aws_appautoscaling_target.cache[each.key].scalable_dimension
  name               = "${var.workspace}-redis-cache-autoscaling-memory-${each.key}"
  policy_type        = "TargetTrackingScaling"

  # adjust the number of nodes up or down to try to keep memory usage at target_value
  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 600
    scale_out_cooldown = 600

    predefined_metric_specification {
      predefined_metric_type = "ElastiCacheDatabaseMemoryUsageCountedForEvictPercentage"
    }
  }
}

resource "aws_appautoscaling_policy" "cache_cpu" {
  for_each = local.cache_autoscaling_targets

  resource_id        = aws_appautoscaling_target.cache[each.key].resource_id
  service_namespace  = aws_appautoscaling_target.cache[each.key].service_namespace
  scalable_dimension = aws_appautoscaling_target.cache[each.key].scalable_dimension
  name               = "${var.workspace}-redis-cache-autoscaling-cpu-${each.key}"
  policy_type        = "TargetTrackingScaling"

  # adjust the number of nodes up or down to try to keep cpu usage at target_value
  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 600
    scale_out_cooldown = 600

    predefined_metric_specification {
      predefined_metric_type = "ElastiCachePrimaryEngineCPUUtilization"
    }
  }
}

# Agent OS cache: dedicated ElastiCache Valkey 7.2 replication group, isolated from the
# Paragon/Managed Sync Redis instances above. App env keys stay REDIS_* (Redis-compatible API).

locals {
  agent_os_valkey_config_defaults = {
    node_type       = "cache.t4g.medium"
    multi_az        = true
    cluster_enabled = false
  }

  # Partial overrides set omitted attributes to null; drop them so defaults survive the merge.
  agent_os_valkey_config = merge(
    local.agent_os_valkey_config_defaults,
    { for key, value in try(var.agent_os_valkey["cache"], {}) : key => value if value != null },
  )

  agent_os_valkey_version = "7.2"
}

data "aws_ec2_instance_type_offerings" "agent_os_cache_filter" {
  count = var.agent_os_enabled ? 1 : 0

  filter {
    name   = "instance-type"
    values = [trimprefix(local.agent_os_valkey_config.node_type, "cache.")]
  }

  filter {
    name   = "location"
    values = var.private_subnet[*].availability_zone
  }

  location_type = "availability-zone"
}

locals {
  agent_os_cache_subnet_ids = var.agent_os_enabled ? [
    for subnet in var.private_subnet : subnet.id
    if contains(data.aws_ec2_instance_type_offerings.agent_os_cache_filter[0].locations, subnet.availability_zone)
  ] : []
}

resource "random_password" "agent_os_valkey_auth" {
  count = var.agent_os_enabled ? 1 : 0

  length           = 64
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_elasticache_subnet_group" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name       = "${var.workspace}-agent-os-valkey-subnet"
  subnet_ids = local.agent_os_cache_subnet_ids
}

resource "aws_elasticache_parameter_group" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name   = "${var.workspace}-agent-os-valkey${split(".", local.agent_os_valkey_version)[0]}"
  family = "valkey${split(".", local.agent_os_valkey_version)[0]}"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "30"
  }

  parameter {
    name  = "timeout"
    value = "120"
  }

  parameter {
    name  = "cluster-enabled"
    value = local.agent_os_valkey_config.cluster_enabled ? "yes" : "no"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.workspace}-agent-os-valkey"
  }
}

resource "aws_elasticache_replication_group" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  # Replication group IDs are capped at 40 characters.
  replication_group_id = "${substr(replace("${var.workspace}-agent-os", "_", "-"), 0, 32)}-vk"
  description          = "Agent OS Valkey cache."
  apply_immediately    = true
  node_type            = local.agent_os_valkey_config.node_type
  engine               = "valkey"
  engine_version       = local.agent_os_valkey_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.agent_os[0].name

  snapshot_retention_limit = 5
  snapshot_window          = "12:00-13:00"
  maintenance_window       = "tue:16:00-tue:17:00"

  subnet_group_name          = aws_elasticache_subnet_group.agent_os[0].name
  security_group_ids         = [aws_security_group.agent_os[0].id]
  multi_az_enabled           = local.agent_os_valkey_config.multi_az
  automatic_failover_enabled = local.agent_os_valkey_config.multi_az

  num_node_groups         = local.agent_os_valkey_config.cluster_enabled ? 1 : null
  replicas_per_node_group = local.agent_os_valkey_config.cluster_enabled ? (local.agent_os_valkey_config.multi_az ? 1 : 0) : null
  num_cache_clusters      = local.agent_os_valkey_config.cluster_enabled ? null : (local.agent_os_valkey_config.multi_az ? 2 : 1)

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = var.agent_os_kms_key_arn
  auth_token                 = random_password.agent_os_valkey_auth[0].result

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.agent_os[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.agent_os[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name    = "${var.workspace}-agent-os-valkey"
    Cluster = local.agent_os_valkey_config.cluster_enabled ? "true" : "false"
  }
}

resource "aws_cloudwatch_log_group" "agent_os" {
  count = var.agent_os_enabled ? 1 : 0

  name              = "/aws/elasticache/${var.workspace}-agent-os"
  retention_in_days = 365
  kms_key_id        = var.agent_os_kms_key_arn
}
