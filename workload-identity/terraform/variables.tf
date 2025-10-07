variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-workload-identity"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-workload-identity"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aks-wi"
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
  default     = "id-workload-identity"
}

variable "federated_credential_name" {
  description = "Name of the federated identity credential"
  type        = string
  default     = "federated-credential"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "default"
}

variable "kubernetes_service_account" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "workload-identity-sa"
}

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique)"
  type        = string
  default     = "stwi"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Lab"
    Purpose     = "WorkloadIdentity"
  }
}
