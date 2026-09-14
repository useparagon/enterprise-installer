variable "gcp_project_id" {
  description = "The GCP region to deploy resources"
  type        = string
}

variable "network" {
  description = "The Virtual network  where our resources will be deployed"
}

variable "private_subnet" {
  description = "The private subnet in our virtual network"
}

variable "region" {
  description = "The region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone" {
  description = "The zone in the region where to host Google Cloud Organization resources."
  type        = string
}

variable "region_zone_backup" {
  description = "The backup zone in the region where to host Google Cloud Organization resources."
  type        = string
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "k8s_version" {
  description = "The version of Kubernetes to run in the cluster."
  type        = string
}

variable "k8s_min_node_count" {
  description = "Minimum number of node Kubernetes can scale down to."
  type        = number
}

variable "k8s_max_node_count" {
  description = "Maximum number of node Kubernetes can scale up to."
  type        = number
}

variable "k8s_spot_instance_percent" {
  description = "The percentage of spot instances to use for Kubernetes nodes."
  type        = number
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
}

variable "disable_deletion_protection" {
  description = "Used to disable deletion protection on GKE resources."
  type        = bool
}

variable "disable_public_endpoint" {
  description = "Used to disable public endpoint on GKE cluster."
  type        = bool
}

variable "k8s_master_authorized_networks" {
  description = "List of CIDRs allowed to reach the GKE control plane. Empty = restricted (only node IPs). Use [{ cidr_block = \"0.0.0.0/0\", display_name = \"all\" }] to allow all."
  type = list(object({
    cidr_block   = string
    display_name = optional(string, "")
  }))
  default = []
}

variable "agent_os_enabled" {
  type    = bool
  default = false
}

variable "agent_os_index_machine_type" {
  type    = string
  default = "n2-highmem-8"
}

variable "agent_os_index_min_count" {
  type    = number
  default = 2
}

variable "agent_os_index_max_count" {
  type    = number
  default = 4
}

variable "agent_os_extract_machine_type" {
  description = "Compute-optimized AMD machine type for the Agent OS extraction node pool."
  type        = string
  default     = "c2d-standard-16"
}

variable "agent_os_extract_min_count" {
  description = "Minimum nodes in the Agent OS extraction node pool."
  type        = number
  default     = 1
}

variable "agent_os_extract_max_count" {
  description = "Maximum nodes in the Agent OS extraction node pool."
  type        = number
  default     = 8
}
