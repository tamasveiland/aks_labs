# AKS Labs

This repository contains sample implementations for different use cases and scenarios with Azure Kubernetes Service (AKS).

## Available Labs

### 1. [Workload Identity](./workload-identity/)

Demonstrates how to configure and use Azure AD Workload Identity with AKS using Terraform. This lab covers:
- Setting up an AKS cluster with OIDC issuer and workload identity enabled
- Creating user-assigned managed identities and federated credentials
- Deploying workloads that authenticate to Azure services using workload identity
- Accessing Azure Storage using workload identity without secrets

**Technologies**: Terraform, AKS, Azure AD Workload Identity, Azure Storage

### 2. [Key Vault Integration](./key-vault-integration/)

Demonstrates how to integrate AKS with Azure Key Vault using Azure AD Workload Identity. This lab covers:
- Setting up an AKS cluster with OIDC issuer and workload identity enabled
- Configuring Azure Key Vault with RBAC authorization
- Creating managed identities with Key Vault access permissions
- Deploying workloads that securely retrieve secrets from Key Vault without credentials
- Implementing security best practices for secret management

**Technologies**: Terraform, AKS, Azure AD Workload Identity, Azure Key Vault

## Prerequisites

To work with these labs, you'll need:
- An active Azure subscription
- Azure CLI installed and configured
- Terraform >= 1.0 (for Terraform-based labs)
- kubectl installed

## Getting Started

Each lab has its own directory with:
- Infrastructure as Code (Terraform or Bicep)
- Kubernetes manifests
- Detailed README with step-by-step instructions

Navigate to the specific lab directory and follow the README instructions.

## Contributing

Feel free to contribute additional labs or improvements to existing ones!
