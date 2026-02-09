
# Get the current Azure tenant and client configuration
data "azurerm_client_config" "current" {}

resource "random_string" "random_suffix" {
  length  = 10
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = var.workload_identity_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = var.tags
}

resource "azurerm_federated_identity_credential" "federated_credential" {
  name                = var.federated_credential_name
  resource_group_name = azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${var.kubernetes_namespace}:${var.kubernetes_service_account}"
}

resource "azurerm_key_vault" "keyvault" {
  name                       = "kv${random_string.random_suffix.result}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Enable RBAC authorization for Key Vault
  enable_rbac_authorization = true

  tags = var.tags
}

# Grant the workload identity Key Vault Secrets User role
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}

# Grant the current user/service principal Key Vault Administrator role to create secrets
resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Create sample secrets in Key Vault
resource "azurerm_key_vault_secret" "database_connection_string" {
  name         = "database-connection-string"
  value        = "Server=myserver.database.windows.net;Database=mydb;User Id=myuser;Password=P@ssw0rd123;"
  key_vault_id = azurerm_key_vault.keyvault.id

  depends_on = [azurerm_role_assignment.keyvault_admin]
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "api-key"
  value        = "my-secret-api-key-12345"
  key_vault_id = azurerm_key_vault.keyvault.id

  depends_on = [azurerm_role_assignment.keyvault_admin]
}

resource "azurerm_key_vault_secret" "application_secret" {
  name         = "application-secret"
  value        = "super-secret-value-67890"
  key_vault_id = azurerm_key_vault.keyvault.id

  depends_on = [azurerm_role_assignment.keyvault_admin]
}
