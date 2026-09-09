variable "resource_group" {
  description = "The resource group to associate resources."
}

variable "private_subnet" {
  description = "Private subnet accessible only within the virtual network to deploy to."
}

variable "aks_nsg_id" {
  description = "NSG associated with the AKS private subnet. Required so the cluster identity can reconcile LoadBalancer security rules."
  type        = string
}

variable "private_subnet_nat_gateway_id" {
  description = "Private subnet NAT gateway association ID. Required before AKS can use userAssignedNATGateway outbound."
  type        = string
}

variable "workspace" {
  description = "The workspace prefix to use for created resources."
  type        = string
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
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

variable "k8s_default_node_pool_vm_size" {
  description = "VM size for the AKS default (system) node pool. Must be available in the target region (e.g. Standard_B2s_v2 in japaneast)."
  type        = string
}

variable "k8s_ondemand_node_instance_type" {
  description = "The compute instance type to use for Kubernetes on demand nodes."
  type        = string
}

variable "k8s_spot_node_instance_type" {
  description = "The compute instance type to use for Kubernetes spot nodes."
  type        = string
}

variable "k8s_sku_tier" {
  description = "The SKU Tier of the AKS cluster (`Free`, `Standard` or `Premium`)."
  type        = string
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.k8s_sku_tier)
    error_message = "The sku_tier for the AKS cluster. It must be `Free`, `Standard`, or `Premium`."
  }
}

variable "k8s_network_plugin" {
  description = "AKS network plugin. Use `azure` (recommended) or legacy `kubenet`."
  type        = string
  validation {
    condition     = contains(["azure", "kubenet"], var.k8s_network_plugin)
    error_message = "k8s_network_plugin must be `azure` or `kubenet`."
  }
}

variable "k8s_network_plugin_mode" {
  description = "Azure CNI mode. `overlay` assigns pod IPs from k8s_pod_cidr (default, IP-efficient). Set to null for legacy node-subnet mode (pod IPs from the VNet)."
  type        = string
  default     = "overlay"
  validation {
    condition     = var.k8s_network_plugin_mode == null || var.k8s_network_plugin_mode == "overlay"
    error_message = "k8s_network_plugin_mode must be null or `overlay`."
  }
}

variable "k8s_pod_cidr" {
  description = "Pod overlay CIDR (RFC 1918 private). Used when k8s_network_plugin_mode is `overlay` or k8s_network_plugin is `kubenet`. Must not overlap vpc_cidr or k8s_service_cidr."
  type        = string
  default     = "192.168.0.0/16"

  validation {
    condition     = (var.k8s_network_plugin != "kubenet" && var.k8s_network_plugin_mode != "overlay") || var.k8s_pod_cidr != null
    error_message = "k8s_pod_cidr is required when k8s_network_plugin_mode is overlay or k8s_network_plugin is kubenet."
  }
}

variable "k8s_service_cidr" {
  description = "Kubernetes service CIDR block. Immutable after cluster creation."
  type        = string
}

variable "k8s_dns_service_ip" {
  description = "IP address within k8s_service_cidr for the cluster DNS service. Immutable after cluster creation."
  type        = string
}

variable "k8s_outbound_type" {
  description = "AKS outbound connectivity type. Use `userAssignedNATGateway` when the private subnet has a NAT Gateway (recommended)."
  type        = string
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway", "userAssignedNATGateway"], var.k8s_outbound_type)
    error_message = "k8s_outbound_type must be one of: loadBalancer, userDefinedRouting, managedNATGateway, userAssignedNATGateway."
  }
}

variable "k8s_load_balancer_sku" {
  description = "SKU for the AKS load balancer."
  type        = string
  validation {
    condition     = contains(["basic", "standard"], var.k8s_load_balancer_sku)
    error_message = "k8s_load_balancer_sku must be `basic` or `standard`."
  }
}

variable "k8s_network_policy" {
  description = "Network policy engine. Leave null to disable, or set to `azure`, `calico`, or `cilium`."
  type        = string
  default     = null
  validation {
    condition     = var.k8s_network_policy == null ? true : contains(["azure", "calico", "cilium"], var.k8s_network_policy)
    error_message = "k8s_network_policy must be null, `azure`, `calico`, or `cilium`."
  }
}
