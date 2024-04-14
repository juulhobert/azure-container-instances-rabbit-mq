resource "azurerm_subnet" "app_subnet" {
  address_prefixes = ["10.0.3.0/24"]
  name                 = "app-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  delegation {
    name = "delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_service_plan" "plan" {
  name                = "serviceplan"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "sender" {
  name                = "sender-app"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    minimum_tls_version    = "1.2"
    ftps_state             = "Disabled"
    http2_enabled          = true
    use_32_bit_worker      = false

    application_stack {
      java_server         = "JAVA"
      java_version        = "17"
      java_server_version = "17"
    }
  }
  virtual_network_subnet_id = azurerm_subnet.app_subnet.id

  app_settings = {
    "RABBITMQ_HOST" = azurerm_container_group.node1.ip_address
  }
}

resource "azurerm_linux_web_app" "receiver" {
  name                = "receiver-app2"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    minimum_tls_version    = "1.2"
    ftps_state             = "Disabled"
    http2_enabled          = true
    use_32_bit_worker      = false

    application_stack {
      java_server         = "JAVA"
      java_version        = "17"
      java_server_version = "17"
    }
  }
  virtual_network_subnet_id = azurerm_subnet.app_subnet.id

  app_settings = {
    "RABBITMQ_HOST" = azurerm_container_group.node1.ip_address
  }
}