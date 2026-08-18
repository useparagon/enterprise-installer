variable "enabled" {
  description = "Whether to deploy Application Gateway for Containers (AGC) and the ALB controller."
  type        = bool
  default     = false
}

variable "direct_routing" {
  description = "false = AGC forwards to the ingress-nginx Service (transition); true = AGC routes directly to application Services via Gateway API (final state, nginx removed)."
  type        = bool
  default     = false
}

variable "workspace" {
  description = "Workspace prefix for AGC resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that owns the AGC resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name (used to read kube config and the OIDC issuer)."
  type        = string
}

variable "subnet_id" {
  description = "Dedicated AGC association subnet ID (delegated to Microsoft.ServiceNetworking/trafficControllers)."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace that holds the Gateway, HTTPRoutes and the wildcard TLS secret."
  type        = string
}

variable "domain" {
  description = "Root domain used for the HTTPS listener hostname (*.domain)."
  type        = string
}

variable "nginx_service_name" {
  description = "ingress-nginx controller Service name used as the AGC backend during transition."
  type        = string
  default     = "ingress-nginx-controller"
}

variable "nginx_service_port" {
  description = "ingress-nginx controller Service port used as the AGC backend during transition."
  type        = number
  default     = 80
}

variable "public_services" {
  description = "Public services for direct routing. Map of service name to host + backend port."
  type = map(object({
    host = string
    port = number
  }))
  default = {}
}

# Kept separate from waf_policy_id: on a greenfield apply the policy ID is unknown until
# the WAF policy is created, so it cannot gate a count.
variable "waf_enabled" {
  description = "Whether to attach the WAF policy to AGC through a security policy."
  type        = bool
  default     = false
}

variable "waf_policy_id" {
  description = "Azure WAF policy ID to associate with AGC. Required when waf_enabled is true."
  type        = string
  default     = null
}

variable "alb_controller_version" {
  description = "ALB controller Helm chart version (requires AKS >= 1.27)."
  type        = string
  default     = "1.11.3"
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  gateway_name          = "paragon-agc"
  alb_controller_ns     = "azure-alb-system"
  alb_controller_sa     = "alb-controller-sa"
  gateway_class         = "azure-alb-external"
  http_listener         = "http"
  direct_routes_enabled = var.enabled && var.direct_routing
  nginx_route_enabled   = var.enabled && !var.direct_routing
}
