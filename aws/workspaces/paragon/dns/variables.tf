variable "enabled" {
  description = "Create Route 53 service CNAME records in the ALB hosted zone."
  type        = bool
  default     = true
}

variable "workspace" {
  description = "Application load balancer name (EKS ingress ALB)."
  type        = string
}

variable "domain" {
  description = "Paragon deployment domain (Route 53 zone apex)."
  type        = string
}

variable "route53_zone_id" {
  description = "Hosted zone for service records (from module.alb)."
  type        = string
}

variable "public_microservices" {
  description = "Microservices exposed on the shared ALB."
  type = map(object({
    port             = number
    healthcheck_path = string
    public_url       = string
  }))
}

variable "public_monitors" {
  description = "Monitoring UIs exposed on the shared ALB."
  type = map(object({
    port       = number
    public_url = string
  }))
}

variable "record_ttl" {
  description = "TTL for service CNAME records."
  type        = number
  default     = 300
}
