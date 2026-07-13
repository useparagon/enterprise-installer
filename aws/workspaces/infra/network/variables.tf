variable "workspace" {
  description = "The name of the workspace resources are being created in."
  type        = string
}

variable "aws_region" {
  description = "The AWS region resources are created in."
  type        = string
}

variable "az_count" {
  description = "Number of AZs to cover in a given region."
  type        = number
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
}

variable "vpc_cidr_newbits" {
  description = "Newbits used for calculating subnets."
  type        = number
}

variable "network_firewall_enabled" {
  description = "Whether to create firewall subnets for AWS Network Firewall."
  type        = bool
}

variable "logs_bucket_name" {
  description = "Central S3 logs bucket for Network Firewall logging when enabled."
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
