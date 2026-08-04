variable "workspace" {
  description = "Workspace name used to prefix Grafana IAM resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for Grafana Pod Identity association."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the grafana ServiceAccount lives."
  type        = string
}
