# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = var.vnet_address_space
}

# Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = var.appgw_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.appgw_subnet_address_prefix
}

# Subnet for Backend Pool (e.g., VMs or AKS)
resource "azurerm_subnet" "backend_subnet" {
  name                 = var.backend_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.backend_subnet_address_prefix
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = var.public_ip_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# User Assigned Managed Identity for Application Gateway
resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = "${var.appgw_name}-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Data source for Key Vault (must already exist)
data "azurerm_key_vault" "kv" {
  count               = var.key_vault_name != "" ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

# Data source for Key Vault Certificate
data "azurerm_key_vault_certificate" "cert" {
  count        = var.key_vault_certificate_name != "" ? 1 : 0
  name         = var.key_vault_certificate_name
  key_vault_id = data.azurerm_key_vault.kv[0].id
}

# Key Vault Access Policy for Managed Identity
resource "azurerm_key_vault_access_policy" "appgw_policy" {
  count        = var.key_vault_name != "" ? 1 : 0
  key_vault_id = data.azurerm_key_vault.kv[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_identity.principal_id

  secret_permissions = [
    "Get",
  ]

  certificate_permissions = [
    "Get",
  ]
}

# Current client configuration
data "azurerm_client_config" "current" {}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = var.appgw_sku_name
    tier     = var.appgw_sku_tier
    capacity = var.appgw_capacity
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_identity.id]
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  # Frontend Port for HTTP
  frontend_port {
    name = "http-port"
    port = 80
  }

  # Frontend Port for HTTPS
  frontend_port {
    name = "https-port"
    port = 443
  }

  # Frontend IP Configuration
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  # Backend Address Pool - App1
  backend_address_pool {
    name = "backend-pool-app1"
    # Backend addresses can be added here or dynamically
    # fqdns = ["app1.example.com"]
    # ip_addresses = ["10.0.2.10"]
  }

  # Backend Address Pool - App2
  backend_address_pool {
    name = "backend-pool-app2"
  }

  # Backend HTTP Settings for App1
  backend_http_settings {
    name                  = "backend-http-settings-app1"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "health-probe-app1"
  }

  # Backend HTTP Settings for App2 (HTTPS)
  backend_http_settings {
    name                  = "backend-http-settings-app2"
    cookie_based_affinity = "Enabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 30
    probe_name            = "health-probe-app2"
    pick_host_name_from_backend_address = true
  }

  # Health Probe for App1
  probe {
    name                                      = "health-probe-app1"
    protocol                                  = "Http"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    host                                      = "127.0.0.1"
    match {
      status_code = ["200-399"]
    }
  }

  # Health Probe for App2
  probe {
    name                                      = "health-probe-app2"
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # HTTP Listener
  # http_listener {
  #   name                           = "http-listener"
  #   frontend_ip_configuration_name = "appgw-frontend-ip"
  #   frontend_port_name             = "http-port"
  #   protocol                       = "Http"
  # }

  # HTTPS Listener (using Key Vault certificate)
  dynamic "http_listener" {
    for_each = var.key_vault_certificate_name != "" ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "appgw-frontend-ip"
      frontend_port_name             = "https-port"
      protocol                       = "Https"
      ssl_certificate_name           = "appgw-ssl-cert"
    }
  }

  # Path-based Listener for multiple apps
  http_listener {
    name                           = "path-based-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # Basic Routing Rule - HTTP to App1
  request_routing_rule {
    name                       = "rule-http-app1"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool-app1"
    backend_http_settings_name = "backend-http-settings-app1"
    priority                   = 100
  }

  # Path-based Routing Rule
  request_routing_rule {
    name               = "rule-path-based"
    rule_type          = "PathBasedRouting"
    http_listener_name = "path-based-listener"
    url_path_map_name  = "path-map"
    priority           = 200
  }

  # HTTPS Routing Rule (if HTTPS listener is configured)
  dynamic "request_routing_rule" {
    for_each = var.key_vault_certificate_name != "" ? [1] : []
    content {
      name                       = "rule-https-app1"
      rule_type                  = "Basic"
      http_listener_name         = "https-listener"
      backend_address_pool_name  = "backend-pool-app1"
      backend_http_settings_name = "backend-http-settings-app1"
      priority                   = 300
    }
  }

  # URL Path Map for path-based routing
  url_path_map {
    name                               = "path-map"
    default_backend_address_pool_name  = "backend-pool-app1"
    default_backend_http_settings_name = "backend-http-settings-app1"

    path_rule {
      name                       = "path-rule-app1"
      paths                      = ["/app1/*"]
      backend_address_pool_name  = "backend-pool-app1"
      backend_http_settings_name = "backend-http-settings-app1"
    }

    path_rule {
      name                       = "path-rule-app2"
      paths                      = ["/app2/*"]
      backend_address_pool_name  = "backend-pool-app2"
      backend_http_settings_name = "backend-http-settings-app2"
    }
  }

  # SSL Certificate from Key Vault
  dynamic "ssl_certificate" {
    for_each = var.key_vault_certificate_name != "" ? [1] : []
    content {
      name                = "appgw-ssl-cert"
      key_vault_secret_id = data.azurerm_key_vault_certificate.cert[0].secret_id
    }
  }

  lifecycle {
    ignore_changes = [ 
        ssl_certificate
     ]
  }

  tags = var.tags
}
