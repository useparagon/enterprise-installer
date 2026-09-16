variable "enabled" {
  description = "Whether to create Azure DNS service records."
  type        = bool
  default     = true
}

variable "zone_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "domain" {
  type = string
}

variable "ingress_loadbalancer" {
  type = string
}

variable "public_services" {
  type = map(object({
    port       = number
    public_url = string
  }))
}

variable "record_ttl" {
  type    = number
  default = 300
}

locals {
  is_ip = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.ingress_loadbalancer))

  record_names = {
    for key, svc in var.public_services :
    key => (
      length(trimsuffix(
        replace(replace(svc.public_url, "https://", ""), "http://", ""),
        ".${var.domain}"
      )) > 0
      ? trimsuffix(
        replace(replace(svc.public_url, "https://", ""), "http://", ""),
        ".${var.domain}"
      )
      : "@"
    )
  }
}
