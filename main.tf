locals {
  location = "westeurope"
  storage_account_name = "playgroundrabbitmq"
  search_domain = "playgroundrabbitmq.tech"
}

data "azurerm_resource_group" "rg" {
  name = "playground-rabbitmq"
}

resource "azurerm_container_registry" "acr" {
  name                = "juulstechacr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_role_assignment" "acr_container_group_node1_assignment" {
  principal_id                     = azurerm_user_assigned_identity.nodes_identity.principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "azurerm_virtual_network" "vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  name                = "vnet"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "mq-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "private_dns_zone" {
  name                = local.search_domain
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_zone_virtual_network_link" {
  name                  = "vnet-link"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_subnet" "storage" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "st-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_user_assigned_identity" "nodes_identity" {
  location            = data.azurerm_resource_group.rg.location
  name                = "nodes-identity"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_container_group" "node1" {
  location            = local.location
  name                = "juulstech-node1"
  os_type             = "Linux"
  resource_group_name = data.azurerm_resource_group.rg.name
  restart_policy      = "Always"
  zones               = ["1"]
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.subnet.id]

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.nodes_identity.id]
  }

  image_registry_credential {
    user_assigned_identity_id = azurerm_user_assigned_identity.nodes_identity.id
    server = azurerm_container_registry.acr.login_server
  }

  container {
    cpu    = 0.5
    image  = "${azurerm_container_registry.acr.login_server}/rabbitmq:3-management-alpine"
    memory = 0.5
    name   = "rabbitmq"

    ports {
      port     = 15672
      protocol = "TCP"
    }
    ports {
      port     = 5672
      protocol = "TCP"
    }
    volume {
      mount_path           = "/var/lib/rabbitmq/mnesia"
      name                 = "data"
      storage_account_name = azurerm_storage_account.sa.name
      storage_account_key  = azurerm_storage_account.sa.primary_access_key
      share_name           = azurerm_storage_share.share1.name
    }
  }
}

resource "azurerm_private_dns_a_record" "private_dns_a_record" {
  name                = azurerm_container_group.node1.name
  records             = [azurerm_container_group.node1.ip_address]
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  zone_name           = azurerm_private_dns_zone.private_dns_zone.name
}

resource "azurerm_storage_account" "sa" {
  account_replication_type      = "ZRS"
  account_tier                  = "Standard"
  location                      = "westeurope"
  name                          = local.storage_account_name
  resource_group_name           = data.azurerm_resource_group.rg.name
  public_network_access_enabled = true
  min_tls_version               = "TLS1_2"
  nfsv3_enabled                 = false
  enable_https_traffic_only     = true
}

resource "azurerm_private_endpoint" "private_endpoint" {
  name                = "strabbitmqdemo"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.storage.id

  private_service_connection {
    name                           = "psc-${local.storage_account_name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["file"]
  }
}

resource "azurerm_storage_share" "share1" {
  name                 = "share1"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 50
}