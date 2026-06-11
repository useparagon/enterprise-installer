resource "azurerm_resource_group" "main" {
  name = "${var.workspace}-resources"

  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "main" {
  name = "${var.workspace}-network"

  address_space       = [var.vpc_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# subnet for general public resources
resource "azurerm_subnet" "public" {
  name = "${var.workspace}-public-subnet"

  address_prefixes     = [cidrsubnet(var.vpc_cidr, 4, 0)]
  resource_group_name  = azurerm_resource_group.main.name
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.main.name
}

# subnet for general private resources
resource "azurerm_subnet" "private" {
  name = "${var.workspace}-private-subnet"

  address_prefixes     = [cidrsubnet(var.vpc_cidr, 4, 1)]
  resource_group_name  = azurerm_resource_group.main.name
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.main.name
}

# subnet specifically for postgres resources
resource "azurerm_subnet" "postgres" {
  name = "${var.workspace}-postgres-subnet"

  address_prefixes     = [cidrsubnet(var.vpc_cidr, 4, 2)]
  resource_group_name  = azurerm_resource_group.main.name
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.main.name

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# subnet specifically for redis resources
resource "azurerm_subnet" "redis" {
  name = "${var.workspace}-redis-subnet"

  address_prefixes     = [cidrsubnet(var.vpc_cidr, 4, 3)]
  resource_group_name  = azurerm_resource_group.main.name
  service_endpoints    = ["Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.main.name
}

# NAT Gateway provides scalable outbound SNAT for private subnet workloads (AKS nodes,
# bastion). Without it, AKS defaults to load balancer outbound SNAT, which pre-allocates
# ~1024 ports per node and exhausts under high connection counts.
resource "azurerm_public_ip" "nat" {
  name                = "${var.workspace}-nat-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                = "${var.workspace}-nat-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}
