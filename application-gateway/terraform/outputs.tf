output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "application_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.appgw.name
}

output "application_gateway_id" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.id
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "public_ip_fqdn" {
  description = "FQDN of the Application Gateway public IP"
  value       = azurerm_public_ip.appgw_pip.fqdn
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.vnet.name
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw_subnet.id
}

output "backend_subnet_id" {
  description = "ID of the backend subnet"
  value       = azurerm_subnet.backend_subnet.id
}

output "backend_pool_ids" {
  description = "IDs of the backend address pools"
  value = {
    app1 = [for pool in azurerm_application_gateway.appgw.backend_address_pool : pool.id if pool.name == "backend-pool-app1"][0]
    app2 = [for pool in azurerm_application_gateway.appgw.backend_address_pool : pool.id if pool.name == "backend-pool-app2"][0]
  }
}

output "managed_identity_id" {
  description = "ID of the managed identity used by Application Gateway"
  value       = azurerm_user_assigned_identity.appgw_identity.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the managed identity"
  value       = azurerm_user_assigned_identity.appgw_identity.principal_id
}

output "https_enabled" {
  description = "Whether HTTPS listener is configured"
  value       = var.key_vault_certificate_name != "" ? true : false
}

output "certificate_name" {
  description = "Name of the certificate being used from Key Vault"
  value       = var.key_vault_certificate_name != "" ? data.azurerm_key_vault_certificate.cert[0].name : null
}
