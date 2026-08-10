variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
}

variable "location" {
  description = "The Azure region resources are created in."
  type        = string
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
}

variable "nsg_malicious_ips" {
  description = "Optional list of CIDR prefixes denied by NSG inbound/outbound rules. Empty skips those rules. Azure allows at most 4000 prefixes per rule."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.nsg_malicious_ips) <= 4000
    error_message = "nsg_malicious_ips cannot exceed Azure's 4000 address-prefix limit per NSG rule."
  }
}
