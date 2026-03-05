variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-appgw-demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-appgw"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "appgw_subnet_name" {
  description = "Name of the Application Gateway subnet"
  type        = string
  default     = "snet-appgw"
}

variable "appgw_subnet_address_prefix" {
  description = "Address prefix for the Application Gateway subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "backend_subnet_name" {
  description = "Name of the backend subnet"
  type        = string
  default     = "snet-backend"
}

variable "backend_subnet_address_prefix" {
  description = "Address prefix for the backend subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "public_ip_name" {
  description = "Name of the public IP address"
  type        = string
  default     = "pip-appgw"
}

variable "appgw_name" {
  description = "Name of the Application Gateway"
  type        = string
  default     = "appgw-demo"
}

variable "appgw_sku_name" {
  description = "SKU name for Application Gateway"
  type        = string
  default     = "Standard_v2"
  validation {
    condition     = contains(["Standard_Small", "Standard_Medium", "Standard_Large", "Standard_v2", "WAF_Medium", "WAF_Large", "WAF_v2"], var.appgw_sku_name)
    error_message = "Invalid SKU name. Must be one of: Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, WAF_v2."
  }
}

variable "appgw_sku_tier" {
  description = "SKU tier for Application Gateway"
  type        = string
  default     = "Standard_v2"
  validation {
    condition     = contains(["Standard", "Standard_v2", "WAF", "WAF_v2"], var.appgw_sku_tier)
    error_message = "Invalid SKU tier. Must be one of: Standard, Standard_v2, WAF, WAF_v2."
  }
}

variable "appgw_capacity" {
  description = "Capacity (instance count) for Application Gateway"
  type        = number
  default     = 2
  validation {
    condition     = var.appgw_capacity >= 1 && var.appgw_capacity <= 125
    error_message = "Capacity must be between 1 and 125."
  }
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault containing the SSL certificate"
  type        = string
  default     = ""
}

variable "key_vault_resource_group_name" {
  description = "Resource group name of the Azure Key Vault"
  type        = string
  default     = ""
}

variable "key_vault_certificate_name" {
  description = "Name of the certificate in Azure Key Vault"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    ManagedBy   = "Terraform"
    Purpose     = "Application Gateway Demo"
  }
}
