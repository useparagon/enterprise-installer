terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      # broker_capacity_config on google_managed_kafka_cluster requires >= 7.19.0
      version = ">= 7.19.0, < 8.0.0"
    }
  }
}
