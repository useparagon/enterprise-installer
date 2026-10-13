variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the MSK cluster will be created"
  type        = string
}

variable "private_subnet" {
  description = "The private subnets within the VPC."
  type        = any
}

variable "msk_instance_type" {
  description = "The instance type for the MSK cluster."
  type        = string
}

variable "msk_kafka_version" {
  description = "The Kafka version for the MSK cluster."
  type        = string
}

variable "msk_kafka_num_broker_nodes" {
  description = "The number of broker nodes for the MSK cluster."
  type        = number
}

variable "msk_autoscaling_enabled" {
  description = "Whether to enable autoscaling for the MSK cluster."
  type        = bool
}

variable "secrets_recovery_window_in_days" {
  description = "Secrets Manager deletion recovery window for the MSK SCRAM credentials secret. Set to 0 for immediate deletion so names are free after destroy."
  type        = number
}
