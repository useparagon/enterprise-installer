# not every instance type is available within each AZ so filter AZs to just those with desired node type
data "aws_ec2_instance_type_offerings" "cache_filter" {
  filter {
    name   = "instance-type"
    values = [substr(local.redis_instances.cache.size, 6, -1)] # strip "cache." to filter
  }
  filter {
    name   = "location"
    values = var.private_subnet[*].availability_zone
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

# Shared Valkey implementation. The workspace root owns the catalog and feature
# enablement. Today it contains only agent_os; future Redis migrations can add
# cache, queue, system, and managed_sync without introducing parallel resources.
locals {
  valkey_names = {
    for key, _ in var.valkey_instances :
    key => "${var.workspace}-${replace(key, "_", "-")}"
  }

  # Replication group IDs are capped at 40 characters. Keep readable IDs when
  # possible and append a stable hash when truncation is required.
  valkey_resource_ids = {
    for key, _ in var.valkey_instances :
    key => length(local.valkey_names[key]) <= 32
    ? local.valkey_names[key]
    : "${substr(local.valkey_names[key], 0, 25)}-${substr(sha1(local.valkey_names[key]), 0, 6)}"
  }
}

data "aws_ec2_instance_type_offerings" "valkey" {
  for_each = var.valkey_instances

  filter {
    name   = "instance-type"
    values = [trimprefix(each.value.node_type, "cache.")]
  }

  filter {
    name   = "location"
    values = var.private_subnet[*].availability_zone
  }

  location_type = "availability-zone"
}

locals {
  valkey_subnet_ids = {
    for key, _ in var.valkey_instances :
    key => [
      for subnet in var.private_subnet : subnet.id
      if contains(data.aws_ec2_instance_type_offerings.valkey[key].locations, subnet.availability_zone)
    ]
  }

  valkey_tls_instances = {
    for key, config in var.valkey_instances :
    key => config
    if config.tls_enabled
  }
}

resource "random_password" "valkey_auth" {
  for_each = local.valkey_tls_instances

  length           = 64
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_elasticache_subnet_group" "valkey" {
  for_each = var.valkey_instances

  name       = "${local.valkey_resource_ids[each.key]}-vk-subnet"
  subnet_ids = local.valkey_subnet_ids[each.key]
}

resource "aws_elasticache_parameter_group" "valkey" {
  for_each = var.valkey_instances

  name   = "${local.valkey_resource_ids[each.key]}-vk${split(".", each.value.engine_version)[0]}"
  family = "valkey${split(".", each.value.engine_version)[0]}"

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
    value = each.value.cluster_enabled ? "yes" : "no"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.valkey_names[each.key]}-valkey"
  }
}

resource "aws_elasticache_replication_group" "valkey" {
  for_each = var.valkey_instances

  replication_group_id = "${local.valkey_resource_ids[each.key]}-vk"
  description          = "Valkey instance for ${each.key}."
  apply_immediately    = true
  node_type            = each.value.node_type
  engine               = "valkey"
  engine_version       = each.value.engine_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.valkey[each.key].name

  snapshot_retention_limit = each.value.snapshot_retention_days
  snapshot_window          = "12:00-13:00"
  maintenance_window       = "tue:16:00-tue:17:00"

  subnet_group_name          = aws_elasticache_subnet_group.valkey[each.key].name
  security_group_ids         = [aws_security_group.valkey[0].id]
  multi_az_enabled           = each.value.multi_az
  automatic_failover_enabled = each.value.multi_az

  num_node_groups         = each.value.cluster_enabled ? 1 : null
  replicas_per_node_group = each.value.cluster_enabled ? (each.value.multi_az ? 1 : 0) : null
  num_cache_clusters      = each.value.cluster_enabled ? null : (each.value.multi_az ? 2 : 1)

  transit_encryption_enabled = each.value.tls_enabled
  at_rest_encryption_enabled = true
  kms_key_id                 = var.valkey_kms_key_arn
  auth_token                 = each.value.tls_enabled ? random_password.valkey_auth[each.key].result : null

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.valkey[each.key].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.valkey[each.key].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name    = "${local.valkey_names[each.key]}-valkey"
    Service = each.key
    Cluster = each.value.cluster_enabled ? "true" : "false"
  }
}

resource "aws_cloudwatch_log_group" "valkey" {
  for_each = var.valkey_instances

  name              = "/aws/elasticache/${local.valkey_names[each.key]}-valkey"
  retention_in_days = each.value.log_retention_days
  kms_key_id        = var.valkey_kms_key_arn
}
