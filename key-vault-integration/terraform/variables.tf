variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-keyvault-integration"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-keyvault-integration"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aks-kv"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Size of the VMs in the node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "workload_identity_name" {
  description = "Name of the user-assigned managed identity for workload identity"
  type        = string
  default     = "id-keyvault-workload"
}

variable "federated_credential_name" {
  description = "Name of the federated identity credential"
  type        = string
  default     = "federated-credential-kv"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "default"
}

variable "kubernetes_service_account" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "keyvault-workload-sa"
}

variable "key_vault_name" {
  description = "Prefix for the Azure Key Vault name (a random suffix will be appended to ensure global uniqueness)"
  type        = string
  default     = "kv-aks-demo"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Lab"
    Purpose     = "KeyVaultIntegration"
  }
}
