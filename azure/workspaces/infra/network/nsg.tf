# Network Security Groups for public/private (AKS) and redis (data) subnets.
# Postgres already has its own NSG in the postgres module.
#
#   aks-nsg        -> baseline + allow 80/443 inbound (ingress + AKS node subnets)
#   default-closed -> baseline only (no inbound HTTP; for data subnets)
#
# Baseline = optional deny for nsg_malicious_ips in/out, deny SSH(22) inbound,
# allow all other outbound. Platform default rules still allow intra-VNet + Azure LB.

resource "azurerm_network_security_group" "aks" {
  name                = "${var.workspace}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = length(var.nsg_malicious_ips) > 0 ? [1] : []
    content {
      name                       = "DenyMaliciousIpsInbound"
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefixes    = var.nsg_malicious_ips
      destination_address_prefix = "*"
    }
  }

  dynamic "security_rule" {
    for_each = length(var.nsg_malicious_ips) > 0 ? [1] : []
    content {
      name                         = "DenyMaliciousIpsOutbound"
      priority                     = 1100
      direction                    = "Outbound"
      access                       = "Deny"
      protocol                     = "*"
      source_port_range            = "*"
      destination_port_range       = "*"
      source_address_prefix        = "*"
      destination_address_prefixes = var.nsg_malicious_ips
    }
  }

  security_rule {
    name                       = "DenyPort22Inbound"
    priority                   = 2000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpInbound"
    priority                   = 2100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 2200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAnyCustomAnyOutbound"
    priority                   = 3100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "default_closed" {
  name                = "${var.workspace}-default-closed-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = length(var.nsg_malicious_ips) > 0 ? [1] : []
    content {
      name                       = "DenyMaliciousIpsInbound"
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefixes    = var.nsg_malicious_ips
      destination_address_prefix = "*"
    }
  }

  dynamic "security_rule" {
    for_each = length(var.nsg_malicious_ips) > 0 ? [1] : []
    content {
      name                         = "DenyMaliciousIpsOutbound"
      priority                     = 1100
      direction                    = "Outbound"
      access                       = "Deny"
      protocol                     = "*"
      source_port_range            = "*"
      destination_port_range       = "*"
      source_address_prefix        = "*"
      destination_address_prefixes = var.nsg_malicious_ips
    }
  }

  security_rule {
    name                       = "DenyPort22Inbound"
    priority                   = 2000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAnyCustomAnyOutbound"
    priority                   = 3100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
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
