# Network Security Groups for public/private (AKS) and redis (data) subnets.
# Postgres already has its own NSG in the postgres module.
#
#   aks-nsg        -> baseline + allow 80/443 inbound (ingress + AKS node subnets)
#   default-closed -> baseline + Premium Redis VNet ports (redis subnet)
#
# Baseline = optional deny for nsg_malicious_ips in/out, deny SSH(22) inbound,
# allow all other outbound. Platform default rules still allow intra-VNet + Azure LB.

locals {
  # Shared baseline applied to both NSGs (keeps deny/allow posture in one place).
  nsg_baseline_rules = concat(
    length(var.nsg_malicious_ips) > 0 ? [
      {
        name                         = "DenyMaliciousIpsInbound"
        priority                     = 1000
        direction                    = "Inbound"
        access                       = "Deny"
        protocol                     = "*"
        source_port_range            = "*"
        destination_port_range       = "*"
        destination_port_ranges      = null
        source_address_prefix        = null
        source_address_prefixes      = var.nsg_malicious_ips
        destination_address_prefix   = "*"
        destination_address_prefixes = null
      },
      {
        name                         = "DenyMaliciousIpsOutbound"
        priority                     = 1100
        direction                    = "Outbound"
        access                       = "Deny"
        protocol                     = "*"
        source_port_range            = "*"
        destination_port_range       = "*"
        destination_port_ranges      = null
        source_address_prefix        = "*"
        source_address_prefixes      = null
        destination_address_prefix   = null
        destination_address_prefixes = var.nsg_malicious_ips
      },
    ] : [],
    [
      {
        name                         = "DenyPort22Inbound"
        priority                     = 2000
        direction                    = "Inbound"
        access                       = "Deny"
        protocol                     = "*"
        source_port_range            = "*"
        destination_port_range       = "22"
        destination_port_ranges      = null
        source_address_prefix        = "*"
        source_address_prefixes      = null
        destination_address_prefix   = "*"
        destination_address_prefixes = null
      },
      {
        name                         = "AllowAnyCustomAnyOutbound"
        priority                     = 3100
        direction                    = "Outbound"
        access                       = "Allow"
        protocol                     = "*"
        source_port_range            = "*"
        destination_port_range       = "*"
        destination_port_ranges      = null
        source_address_prefix        = "*"
        source_address_prefixes      = null
        destination_address_prefix   = "*"
        destination_address_prefixes = null
      },
    ]
  )

  # Extra inbound for public/private (ingress).
  nsg_aks_extra_rules = [
    {
      name                         = "AllowHttpInbound"
      priority                     = 2100
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      source_port_range            = "*"
      destination_port_range       = "80"
      destination_port_ranges      = null
      source_address_prefix        = "*"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
    {
      name                         = "AllowHttpsInbound"
      priority                     = 2200
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      source_port_range            = "*"
      destination_port_range       = "443"
      destination_port_ranges      = null
      source_address_prefix        = "*"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
  ]

  # Premium Azure Cache for Redis VNet injection port requirements:
  # https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-how-to-premium-vnet
  # System tags (VirtualNetwork, AzureLoadBalancer) must use source_address_prefix
  # (singular), not source_address_prefixes. Outbound covered by baseline allow-all.
  nsg_redis_extra_rules = [
    {
      name                         = "AllowRedisClientInbound"
      priority                     = 2100
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      source_port_range            = "*"
      destination_port_range       = null
      destination_port_ranges      = ["6379", "6380"]
      source_address_prefix        = "VirtualNetwork"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
    {
      name                         = "AllowRedisClientFromAzureLBInbound"
      priority                     = 2105
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      source_port_range            = "*"
      destination_port_range       = null
      destination_port_ranges      = ["6379", "6380"]
      source_address_prefix        = "AzureLoadBalancer"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
    {
      name                         = "AllowRedisInternalInbound"
      priority                     = 2110
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      source_port_range            = "*"
      destination_port_range       = null
      destination_port_ranges      = ["8443", "20226"]
      source_address_prefix        = "VirtualNetwork"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
    {
      name                         = "AllowRedisClusterClientInbound"
      priority                     = 2120
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      source_port_range            = "*"
      destination_port_range       = null
      destination_port_ranges      = ["10221-10231", "13000-13999", "15000-15999"]
      source_address_prefix        = "VirtualNetwork"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
    {
      name                         = "AllowRedisClusterFromAzureLBInbound"
      priority                     = 2125
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      source_port_range            = "*"
      destination_port_range       = null
      destination_port_ranges      = ["10221-10231", "13000-13999", "15000-15999"]
      source_address_prefix        = "AzureLoadBalancer"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
    {
      name                         = "AllowRedisAzureLoadBalancerInbound"
      priority                     = 2130
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "*"
      source_port_range            = "*"
      destination_port_range       = null
      destination_port_ranges      = ["8500", "16001"]
      source_address_prefix        = "AzureLoadBalancer"
      source_address_prefixes      = null
      destination_address_prefix   = "*"
      destination_address_prefixes = null
    },
  ]

  nsg_aks_rules   = concat(local.nsg_baseline_rules, local.nsg_aks_extra_rules)
  nsg_redis_rules = concat(local.nsg_baseline_rules, local.nsg_redis_extra_rules)
}

resource "azurerm_network_security_group" "aks" {
  name                = "${var.workspace}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = { for rule in local.nsg_aks_rules : rule.name => rule }
    content {
      name                         = security_rule.value.name
      priority                     = security_rule.value.priority
      direction                    = security_rule.value.direction
      access                       = security_rule.value.access
      protocol                     = security_rule.value.protocol
      source_port_range            = security_rule.value.source_port_range
      destination_port_range       = security_rule.value.destination_port_range
      destination_port_ranges      = security_rule.value.destination_port_ranges
      source_address_prefix        = security_rule.value.source_address_prefix
      source_address_prefixes      = security_rule.value.source_address_prefixes
      destination_address_prefix   = security_rule.value.destination_address_prefix
      destination_address_prefixes = security_rule.value.destination_address_prefixes
    }
  }
}

resource "azurerm_network_security_group" "default_closed" {
  name                = "${var.workspace}-default-closed-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = { for rule in local.nsg_redis_rules : rule.name => rule }
    content {
      name                         = security_rule.value.name
      priority                     = security_rule.value.priority
      direction                    = security_rule.value.direction
      access                       = security_rule.value.access
      protocol                     = security_rule.value.protocol
      source_port_range            = security_rule.value.source_port_range
      destination_port_range       = security_rule.value.destination_port_range
      destination_port_ranges      = security_rule.value.destination_port_ranges
      source_address_prefix        = security_rule.value.source_address_prefix
      source_address_prefixes      = security_rule.value.source_address_prefixes
      destination_address_prefix   = security_rule.value.destination_address_prefix
      destination_address_prefixes = security_rule.value.destination_address_prefixes
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "redis" {
  subnet_id                 = azurerm_subnet.redis.id
  network_security_group_id = azurerm_network_security_group.default_closed.id
}
