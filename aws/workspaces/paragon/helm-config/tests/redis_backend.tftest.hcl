mock_provider "random" {}
mock_provider "tls" {}

variables {
  aws_region = "us-east-1"
  domain     = "example.internal"
  microservices = {
    flipt              = { port = 8080 }
    "queue-exporter"   = { port = 1806 }
    "api-triggerkit"   = { port = 8081 }
    "worker-actionkit" = { port = 8082 }
    "worker-eventlogs" = { port = 8083 }
  }
  infra_values = {
    postgres = { value = {
      managed_sync = { host = "pg.internal", port = 5432, user = "app", password = "placeholder", database = "app" }
      paragon      = { host = "pg.internal", port = 5432, user = "app", password = "placeholder", database = "app" }
    } }
    redis = { value = {
      cache    = { host = "redis-cache.internal", port = 6379, cluster = false, ssl = false }
      workflow = { host = "redis-cache.internal", port = 6379, cluster = false, ssl = false }
    } }
    kafka = { value = {
      cluster_bootstrap_brokers = "kafka.internal:9092"
      cluster_username          = "test"
      cluster_password          = "placeholder"
      cluster_mechanism         = "SCRAM-SHA-512"
      cluster_tls_enabled       = true
    } }
    storage = { value = {
      public_bucket       = "test-public"
      managed_sync_bucket = "test-managed-sync"
    } }
  }
  base_helm_values = {
    global = { env = {
      MANAGED_SYNC_REDIS_URL                         = "redis-cache.internal:6379"
      MANAGED_SYNC_REDIS_CLUSTER_ENABLED             = "false"
      MANAGED_SYNC_REDIS_TLS_ENABLED                 = "false"
      WORKFLOW_REDIS_URL                             = "redis-cache.internal:6379"
      MANAGED_SYNC_KAFKA_SKIP_CONTEXT_TOPIC_CREATION = "true"
    } }
  }
}

run "redis_original_unchanged" {
  command = plan
  assert {
    condition = (
      output.config.MANAGED_SYNC_REDIS_URL == "redis-cache.internal:6379" &&
      output.config.WORKFLOW_REDIS_URL == "redis-cache.internal:6379" &&
      output.config.MANAGED_SYNC_REDIS_CLUSTER_ENABLED == "false"
    )
    error_message = "The existing Redis source and variable names must be preserved."
  }
  assert {
    condition     = output.config.MANAGED_SYNC_KAFKA_SKIP_CONTEXT_TOPIC_CREATION == "true"
    error_message = "Other Managed Sync settings must keep their original flow."
  }
}

run "valkey_shared_same_contract" {
  command = plan
  variables {
    infra_values = {
      postgres = { value = {
        managed_sync = { host = "pg.internal", port = 5432, user = "app", password = "placeholder", database = "app" }
        paragon      = { host = "pg.internal", port = 5432, user = "app", password = "placeholder", database = "app" }
      } }
      redis = { value = {
        cache        = { host = "valkey-cache.internal", port = 6379, cluster = false, ssl = false }
        workflow     = { host = "valkey-cache.internal", port = 6379, cluster = false, ssl = false }
        managed_sync = { host = "valkey-cache.internal", port = 6379, cluster = false, ssl = false }
      } }
      kafka = { value = {
        cluster_bootstrap_brokers = "kafka.internal:9092"
        cluster_username          = "test"
        cluster_password          = "placeholder"
        cluster_mechanism         = "SCRAM-SHA-512"
        cluster_tls_enabled       = true
      } }
      storage = { value = { public_bucket = "test-public", managed_sync_bucket = "test-managed-sync" } }
    }
    base_helm_values = {
      global = { env = {
        MANAGED_SYNC_REDIS_URL                         = "valkey-cache.internal:6379"
        MANAGED_SYNC_REDIS_CLUSTER_ENABLED             = "false"
        MANAGED_SYNC_REDIS_TLS_ENABLED                 = "false"
        WORKFLOW_REDIS_URL                             = "valkey-cache.internal:6379"
        MANAGED_SYNC_KAFKA_SKIP_CONTEXT_TOPIC_CREATION = "true"
      } }
    }
  }
  assert {
    condition = (
      output.config.MANAGED_SYNC_REDIS_URL == "valkey-cache.internal:6379" &&
      output.config.WORKFLOW_REDIS_URL == "valkey-cache.internal:6379"
    )
    error_message = "Shared Valkey must use cache for both Workflow and Managed Sync."
  }
}

run "valkey_multiple_same_contract" {
  command = plan
  variables {
    infra_values = {
      postgres = { value = {
        managed_sync = { host = "pg.internal", port = 5432, user = "app", password = "placeholder", database = "app" }
        paragon      = { host = "pg.internal", port = 5432, user = "app", password = "placeholder", database = "app" }
      } }
      redis = { value = {
        cache        = { host = "valkey-cache.internal", port = 6379, cluster = true, ssl = false }
        workflow     = { host = "valkey-cache.internal", port = 6379, cluster = true, ssl = false }
        managed_sync = { host = "valkey-managed-sync.internal", port = 6379, cluster = true, ssl = false }
      } }
      kafka = { value = {
        cluster_bootstrap_brokers = "kafka.internal:9092"
        cluster_username          = "test"
        cluster_password          = "placeholder"
        cluster_mechanism         = "SCRAM-SHA-512"
        cluster_tls_enabled       = true
      } }
      storage = { value = { public_bucket = "test-public", managed_sync_bucket = "test-managed-sync" } }
    }
    base_helm_values = {
      global = { env = {
        MANAGED_SYNC_REDIS_URL             = "valkey-managed-sync.internal:6379"
        MANAGED_SYNC_REDIS_CLUSTER_ENABLED = "true"
        MANAGED_SYNC_REDIS_TLS_ENABLED     = "false"
        WORKFLOW_REDIS_URL                 = "valkey-cache.internal:6379"
      } }
    }
  }
  assert {
    condition = (
      output.config.MANAGED_SYNC_REDIS_URL == "valkey-managed-sync.internal:6379" &&
      output.config.WORKFLOW_REDIS_URL == "valkey-cache.internal:6379" &&
      output.config.MANAGED_SYNC_REDIS_CLUSTER_ENABLED == "true"
    )
    error_message = "Separate Managed Sync Valkey must retain the same variable contract and independent endpoint."
  }
}
