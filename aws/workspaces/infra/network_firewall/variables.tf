variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the firewall is deployed."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones."
  type        = number
}

variable "availability_zones" {
  description = "Availability zone names, one per index."
  type        = list(string)
}

variable "firewall_subnet_ids" {
  description = "Firewall subnet IDs, one per AZ."
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "Private route table IDs, one per AZ."
  type        = list(string)
}

variable "main_route_table_id" {
  description = "Main route table ID used by public subnets."
  type        = string
}

variable "nat_gateway_ids" {
  description = "NAT gateway IDs, one per AZ."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks, one per AZ."
  type        = list(string)
}

variable "logs_bucket_name" {
  description = "Central S3 logs bucket for Network Firewall flow and alert logs."
  type        = string
}

variable "network_firewall" {
  description = "Network Firewall configuration. Defaults are defined in the root variables.tf."
  type = object({
    enabled                            = bool
    rule_group_arns                    = list(string)
    stateless_default_actions          = list(string)
    stateless_fragment_default_actions = list(string)
    stateful_rule_order                = string
    stateful_default_actions           = list(string)
  })
}
