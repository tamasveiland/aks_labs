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

### 2. [Application Gateway](./application-gateway/)

Demonstrates how to configure Azure Application Gateway with AKS using Terraform.

**Technologies**: Terraform, AKS, Application Gateway, Key Vault

### 3. [GitHub Actions Runner Controller on AKS](./gh-arc-on-aks/)

Deploys an AKS cluster configured to host GitHub Actions Runner Controller (ARC), enabling self-hosted GitHub Actions runners that autoscale on Kubernetes. Built with Azure Developer CLI (`azd`) and Bicep.

- AKS cluster with dedicated autoscaling runner node pool
- ARC v2 controller and runner scale set via Helm
- Automatic scale-to-zero when no jobs are queued
- Post-provisioning automation via azd hooks

**Technologies**: Azure Developer CLI (azd), Bicep, AKS, Helm, GitHub Actions Runner Controller

## Prerequisites

To work with these labs, you'll need:
- An active Azure subscription
- Azure CLI installed and configured
- Terraform >= 1.0 (for Terraform-based labs)
- Azure Developer CLI (`azd`) >= 1.x (for azd-based labs)
- kubectl installed
- Helm >= 3.x (for Helm-based labs)

## Getting Started

Each lab has its own directory with:
- Infrastructure as Code (Terraform or Bicep)
- Kubernetes manifests
- Detailed README with step-by-step instructions

Navigate to the specific lab directory and follow the README instructions.

## Contributing

Feel free to contribute additional labs or improvements to existing ones!
