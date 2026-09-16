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

# Agent OS caches are driven by the workspace-level map so each Valkey instance can
# be sized and tuned independently from Paragon/Managed Sync Redis.
locals {
  agent_os_valkey_instances = var.agent_os_enabled ? var.agent_os_valkey : {}

  agent_os_valkey_names = {
    for key, _ in local.agent_os_valkey_instances :
    key => key == "cache" ? "${var.workspace}-agent-os" : "${var.workspace}-agent-os-${replace(key, "_", "-")}"
  }

  # ElastiCache IDs have short length limits. Keep a stable cache ID, and make
  # additional map entries collision-safe by reserving room for a key hash.
  agent_os_valkey_resource_ids = {
    for key, _ in local.agent_os_valkey_instances :
    key => key == "cache"
    ? substr(replace("${var.workspace}-agent-os", "_", "-"), 0, 32)
    : "${substr(replace("${var.workspace}-agent-os", "_", "-"), 0, 19)}-${substr(replace(key, "_", "-"), 0, 6)}-${substr(sha1(key), 0, 6)}"
  }
}

data "aws_ec2_instance_type_offerings" "agent_os_cache_filter" {
  for_each = local.agent_os_valkey_instances

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
  agent_os_cache_subnet_ids = {
    for key, _ in local.agent_os_valkey_instances :
    key => [
      for subnet in var.private_subnet : subnet.id
      if contains(data.aws_ec2_instance_type_offerings.agent_os_cache_filter[key].locations, subnet.availability_zone)
    ]
  }
}

resource "random_password" "agent_os_valkey_auth" {
  for_each = local.agent_os_valkey_instances

  length           = 64
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_elasticache_subnet_group" "agent_os" {
  for_each = local.agent_os_valkey_instances

  name       = "${local.agent_os_valkey_resource_ids[each.key]}-vk-subnet"
  subnet_ids = local.agent_os_cache_subnet_ids[each.key]
}

resource "aws_elasticache_parameter_group" "agent_os" {
  for_each = local.agent_os_valkey_instances

  name   = "${local.agent_os_valkey_resource_ids[each.key]}-vk${split(".", each.value.engine_version)[0]}"
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
    Name = "${local.agent_os_valkey_names[each.key]}-valkey"
  }
}

resource "aws_elasticache_replication_group" "agent_os" {
  for_each = local.agent_os_valkey_instances

  # Replication group IDs are capped at 40 characters.
  replication_group_id = "${local.agent_os_valkey_resource_ids[each.key]}-vk"
  description          = "Agent OS Valkey cache ${each.key}."
  apply_immediately    = true
  node_type            = each.value.node_type
  engine               = "valkey"
  engine_version       = each.value.engine_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.agent_os[each.key].name

  snapshot_retention_limit = each.value.snapshot_retention_days
  snapshot_window          = "12:00-13:00"
  maintenance_window       = "tue:16:00-tue:17:00"

  subnet_group_name          = aws_elasticache_subnet_group.agent_os[each.key].name
  security_group_ids         = [aws_security_group.agent_os[0].id]
  multi_az_enabled           = each.value.multi_az
  automatic_failover_enabled = each.value.multi_az

  num_node_groups         = each.value.cluster_enabled ? 1 : null
  replicas_per_node_group = each.value.cluster_enabled ? (each.value.multi_az ? 1 : 0) : null
  num_cache_clusters      = each.value.cluster_enabled ? null : (each.value.multi_az ? 2 : 1)

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = var.agent_os_kms_key_arn
  auth_token                 = random_password.agent_os_valkey_auth[each.key].result

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.agent_os[each.key].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.agent_os[each.key].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name    = "${local.agent_os_valkey_names[each.key]}-valkey"
    Cluster = each.value.cluster_enabled ? "true" : "false"
  }
}

resource "aws_cloudwatch_log_group" "agent_os" {
  for_each = local.agent_os_valkey_instances

  name              = "/aws/elasticache/${local.agent_os_valkey_names[each.key]}"
  retention_in_days = each.value.log_retention_days
  kms_key_id        = var.agent_os_kms_key_arn
}
