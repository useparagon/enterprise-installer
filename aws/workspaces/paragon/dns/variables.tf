variable "enabled" {
  description = "Create Route 53 service CNAME records in the ALB hosted zone."
  type        = bool
  default     = true
}

variable "workspace" {
  description = "Application load balancer name (EKS ingress ALB)."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (elbv2.k8s.aws/cluster tag on the ingress ALB)."
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

variable "public_services" {
  description = "Hosts that need DNS records on the shared load balancer (public microservices, monitors, and managed-sync when not on the restrict allowlist)."
  type = map(object({
    port             = optional(number)
    healthcheck_path = optional(string)
    public_url       = string
  }))
}

variable "record_ttl" {
  description = "TTL for service CNAME records."
  type        = number
  default     = 300
}

variable "release_ingress" {
  description = "Ingress Helm release; record depends_on only (not the ALB data source) for greenfield apply order."
  type        = any
}

variable "release_paragon_logging" {
  description = "Logging Helm release; record depends_on only for greenfield ALB creation order."
  type        = any
}

variable "release_paragon_on_prem" {
  description = "On-prem Helm release; record depends_on only for greenfield ALB creation order."
  type        = any
}

variable "ingress_alb_dns_name_fallback" {
  description = "Ingress ALB DNS name from module.helm (depends_on Helm releases). Used on greenfield apply when tagging-api discovery is still empty; ignored when local discovery succeeds (PARA-26180 chart bumps)."
  type        = string
  default     = null
}
