# AKS Workload Identity Lab

This lab demonstrates how to configure and use Azure AD Workload Identity with Azure Kubernetes Service (AKS) using Terraform.

## Overview

Azure AD Workload Identity for Kubernetes integrates with the Kubernetes native capabilities to federate with external identity providers. This approach is simpler and more secure than the previous pod identity solution.

## Architecture

This lab sets up:
- An AKS cluster with OIDC issuer and workload identity enabled
- A User-Assigned Managed Identity for workload identity
- A Federated Identity Credential linking the managed identity to a Kubernetes service account
- An Azure Storage Account as a sample resource to access
- RBAC role assignment granting the managed identity access to the storage account

## Prerequisites

- Azure subscription
- Azure CLI installed and configured
- Terraform >= 1.0
- kubectl installed

## Deployment Steps

### 1. Configure Terraform Variables

Create a `terraform.tfvars` file in the `terraform/` directory (this file is gitignored):

```hcl
resource_group_name     = "rg-aks-workload-identity"
location                = "eastus"
aks_cluster_name        = "aks-workload-identity"
storage_account_name    = "stwi<unique-suffix>"  # Must be globally unique
```

### 2. Deploy Infrastructure

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### 3. Get AKS Credentials

After deployment, retrieve the AKS credentials:

```bash
az aks get-credentials --resource-group <resource-group-name> --name <aks-cluster-name>
```

Or use the output command:

```bash
terraform output -raw kube_config_command
```

### 4. Deploy Kubernetes Resources

Update the Kubernetes manifests with the actual values from Terraform outputs:

#### Option A: Using Bash (Linux/macOS/WSL)

```bash
# Get the workload identity client ID
export WORKLOAD_IDENTITY_CLIENT_ID=$(terraform output -raw workload_identity_client_id)
export STORAGE_ACCOUNT_NAME=$(terraform output -raw storage_account_name)

# Update the service account manifest
sed "s/\${WORKLOAD_IDENTITY_CLIENT_ID}/$WORKLOAD_IDENTITY_CLIENT_ID/g" ../kubernetes/service-account.yaml | kubectl apply -f -

# Update and apply the deployment
sed "s/\${STORAGE_ACCOUNT_NAME}/$STORAGE_ACCOUNT_NAME/g" ../kubernetes/deployment.yaml | kubectl apply -f -
```

#### Option B: Using PowerShell (Windows)

```powershell
# Get the workload identity client ID and storage account name
$WORKLOAD_IDENTITY_CLIENT_ID = terraform output -raw workload_identity_client_id
$STORAGE_ACCOUNT_NAME = terraform output -raw storage_account_name

# Update the service account manifest
(Get-Content ./kubernetes/service-account.yaml) -replace '\$\{WORKLOAD_IDENTITY_CLIENT_ID\}', $WORKLOAD_IDENTITY_CLIENT_ID | kubectl apply -f -

# Update and apply the deployment
((Get-Content ./kubernetes/deployment.yaml) -replace '\$\{STORAGE_ACCOUNT_NAME\}', $STORAGE_ACCOUNT_NAME) -replace '\$\{WORKLOAD_IDENTITY_CLIENT_ID\}', $WORKLOAD_IDENTITY_CLIENT_ID | kubectl apply -f -
```

### 5. Verify Workload Identity

Check the pod logs to verify the workload identity is working:

```bash
kubectl get pods
kubectl logs deployment/workload-identity-demo
```

The logs should show:
- Azure environment variables (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE)
- Successful login using the managed identity
- List of storage containers (empty if none exist)

## How It Works

1. **OIDC Issuer**: AKS provides an OIDC issuer URL that Kubernetes uses to issue tokens
2. **Federated Identity Credential**: Links the Azure AD managed identity to a specific Kubernetes service account
3. **Service Account Annotation**: The service account is annotated with the client ID of the managed identity
4. **Pod Label**: Pods using workload identity must have the label `azure.workload.identity/use: "true"`
5. **Token Projection**: The Azure Workload Identity webhook injects the necessary environment variables and token file into the pod
6. **Authentication**: Applications use the Azure SDK to automatically authenticate using the projected token

## Key Components

### Terraform Configuration

- `main.tf`: Main infrastructure including AKS, managed identity, federated credential, and storage account
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for use in Kubernetes manifests

### Kubernetes Manifests

- `service-account.yaml`: Service account with workload identity annotation
- `deployment.yaml`: Sample deployment demonstrating workload identity usage

## Testing

You can test the workload identity by:

1. Creating a container in the storage account:
   ```bash
   az storage container create --name test --account-name <storage-account-name> --auth-mode login
   ```

2. Checking if the pod can list it:
   ```bash
   kubectl logs deployment/workload-identity-demo
   ```

## Cleanup

To remove all resources:

```bash
cd terraform/
terraform destroy
```

## References

- [Azure AD Workload Identity for Kubernetes](https://azure.github.io/azure-workload-identity/)
- [Use Azure AD workload identity with AKS](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
