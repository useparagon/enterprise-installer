variable "workspace" {
  description = "The name of the resource group that all resources are associated with."
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster, used to tag the ALB backend security group."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ALB backend security group."
  type        = string
}

variable "domain" {
  description = "The root domain used for the microservices."
  type        = string
}

variable "certificate" {
  description = "Optional ACM certificate ARN of an existing certificate to use with the load balancer."
  type        = string
}

variable "public_services" {
  description = "Hosts that need DNS records on the shared load balancer (public microservices, monitors, and managed-sync when not on the restrict allowlist)."
  type = map(object({
    port             = optional(number)
    healthcheck_path = optional(string)
    public_url       = string
  }))
}

variable "microservices" {
  description = "The microservices running within the system, including those only reachable internally"
  type = map(object({
    port = number
  }))
}

variable "release_ingress" {
  description = "The helm release for the ingress."
  type        = any
}

variable "release_paragon_on_prem" {
  description = "The helm release for the Paragon microservices."
  type        = any
}

variable "worker_security_group_ids" {
  description = "Security groups attached to EKS worker nodes."
  type        = list(string)
}

variable "dns_provider" {
  description = "DNS provider to use."
  type        = string
  default     = "cloudflare"
}

variable "cloudflare_dns_api_token" {
  description = "Cloudflare DNS API token for SSL certificate creation and verification."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id to set CNAMEs."
  type        = string
}

locals {
  has_cloudflare_credentials = var.dns_provider == "cloudflare" && var.cloudflare_dns_api_token != null && var.cloudflare_zone_id != null
}
