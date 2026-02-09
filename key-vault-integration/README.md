# AKS + Azure Key Vault Integration Lab

This lab demonstrates how to integrate Azure Kubernetes Service (AKS) with Azure Key Vault using Azure AD Workload Identity. This approach allows Kubernetes workloads to securely access secrets stored in Azure Key Vault without managing credentials directly.

## Overview

Azure AD Workload Identity for Kubernetes enables pods to authenticate to Azure services using federated identity credentials. This lab showcases how to securely retrieve secrets from Azure Key Vault within an AKS pod.

## Architecture

This lab sets up:
- An AKS cluster with OIDC issuer and workload identity enabled
- A User-Assigned Managed Identity for workload identity
- A Federated Identity Credential linking the managed identity to a Kubernetes service account
- An Azure Key Vault with RBAC authorization enabled
- RBAC role assignment granting the managed identity access to Key Vault secrets
- Sample secrets stored in Key Vault for demonstration

## Prerequisites

- Azure subscription
- Azure CLI installed and configured
- Terraform >= 1.0
- kubectl installed

## Deployment Steps

### 1. Configure Terraform Variables

Create a `terraform.tfvars` file in the `terraform/` directory (this file is gitignored):

```hcl
resource_group_name     = "rg-aks-keyvault-integration"
location                = "eastus"
aks_cluster_name        = "aks-keyvault-integration"
key_vault_name          = "kv"  # Will have unique suffix added
```

### 2. Deploy Infrastructure

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

The Terraform configuration will create:
- AKS cluster with workload identity enabled
- Azure Key Vault with RBAC authorization
- User-assigned managed identity
- Federated identity credential
- Three sample secrets:
  - `database-connection-string`
  - `api-key`
  - `application-secret`

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
# Get the required values from Terraform outputs
export WORKLOAD_IDENTITY_CLIENT_ID=$(terraform output -raw workload_identity_client_id)
export KEY_VAULT_NAME=$(terraform output -raw key_vault_name)
export KEY_VAULT_URI=$(terraform output -raw key_vault_uri)

# Update the service account manifest
sed "s/\${WORKLOAD_IDENTITY_CLIENT_ID}/$WORKLOAD_IDENTITY_CLIENT_ID/g" ../kubernetes/service-account.yaml | kubectl apply -f -

# Update and apply the deployment
sed -e "s|\${KEY_VAULT_NAME}|$KEY_VAULT_NAME|g" \
    -e "s|\${KEY_VAULT_URI}|$KEY_VAULT_URI|g" \
    ../kubernetes/deployment.yaml | kubectl apply -f -
```

#### Option B: Using PowerShell (Windows)

```powershell
# Get the required values from Terraform outputs
$WORKLOAD_IDENTITY_CLIENT_ID = terraform output -raw workload_identity_client_id
$KEY_VAULT_NAME = terraform output -raw key_vault_name
$KEY_VAULT_URI = terraform output -raw key_vault_uri

# Update the service account manifest
(Get-Content ../kubernetes/service-account.yaml) -replace '\$\{WORKLOAD_IDENTITY_CLIENT_ID\}', $WORKLOAD_IDENTITY_CLIENT_ID | kubectl apply -f -

# Update and apply the deployment
(Get-Content ../kubernetes/deployment.yaml) `
    -replace '\$\{KEY_VAULT_NAME\}', $KEY_VAULT_NAME `
    -replace '\$\{KEY_VAULT_URI\}', $KEY_VAULT_URI | kubectl apply -f -
```

### 5. Verify Key Vault Access

Check the pod logs to verify the workload identity is accessing Key Vault successfully:

```bash
kubectl get pods
kubectl logs deployment/keyvault-demo
```

The logs should show:
- Azure environment variables (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE)
- Successful login using the managed identity
- List of secrets in the Key Vault
- Values of the three sample secrets

## How It Works

1. **OIDC Issuer**: AKS provides an OIDC issuer URL that Kubernetes uses to issue tokens
2. **Federated Identity Credential**: Links the Azure AD managed identity to a specific Kubernetes service account
3. **Service Account Annotation**: The service account is annotated with the client ID of the managed identity
4. **Pod Label**: Pods using workload identity must have the label `azure.workload.identity/use: "true"`
5. **Token Projection**: The Azure Workload Identity webhook injects the necessary environment variables and token file into the pod
6. **Authentication**: Applications use the Azure SDK/CLI to automatically authenticate using the projected token
7. **RBAC Authorization**: The managed identity has "Key Vault Secrets User" role to read secrets from Key Vault

## Key Components

### Terraform Configuration

- `main.tf`: Main infrastructure including AKS, managed identity, federated credential, and Key Vault
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for use in Kubernetes manifests
- `provider.tf`: Provider configuration with Key Vault features

### Kubernetes Manifests

- `service-account.yaml`: Service account with workload identity annotation
- `deployment.yaml`: Sample deployment demonstrating Key Vault access

## Security Best Practices

This lab implements several security best practices:

1. **RBAC Authorization**: Key Vault uses Azure RBAC instead of access policies for fine-grained access control
2. **Principle of Least Privilege**: The managed identity only has "Key Vault Secrets User" role (read-only access to secrets)
3. **No Secrets in Code**: Workload identity eliminates the need to store credentials in Kubernetes secrets or code
4. **Federated Authentication**: Uses OpenID Connect for secure, token-based authentication
5. **Audit Trail**: All Key Vault access is logged in Azure Monitor for compliance and security monitoring

## Testing

You can test the Key Vault integration by:

1. Adding a new secret to Key Vault:
   ```bash
   az keyvault secret set --vault-name <key-vault-name> --name test-secret --value "test-value"
   ```

2. Checking if the pod can retrieve it:
   ```bash
   kubectl exec deployment/keyvault-demo -- az keyvault secret show --vault-name <key-vault-name> --name test-secret --query "value" -o tsv
   ```

## Common Use Cases

This pattern is useful for:
- **Database Connection Strings**: Securely store and retrieve database credentials
- **API Keys**: Access third-party service API keys without hardcoding
- **Certificates**: Retrieve SSL/TLS certificates for applications
- **Configuration Secrets**: Store sensitive application configuration
- **Encryption Keys**: Access encryption keys for data protection

## Troubleshooting

### Pod cannot authenticate

If the pod fails to authenticate, verify:
- The service account has the correct annotation with the client ID
- The pod has the label `azure.workload.identity/use: "true"`
- The federated credential subject matches the service account namespace and name
- OIDC issuer is enabled on the AKS cluster

### Cannot access Key Vault secrets

If authentication succeeds but secret access fails, verify:
- The managed identity has the "Key Vault Secrets User" role assignment
- The Key Vault has RBAC authorization enabled
- The secret names are correct (Key Vault secret names must be alphanumeric or hyphens)

### Role assignment propagation

Role assignments can take a few minutes to propagate. If you get permission errors immediately after deployment, wait 2-3 minutes and try again.

## Cleanup

To remove all resources:

```bash
cd terraform/
terraform destroy
```

## References

- [Azure AD Workload Identity for Kubernetes](https://azure.github.io/azure-workload-identity/)
- [Use Azure AD workload identity with AKS](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- [Azure Key Vault Developer's Guide](https://learn.microsoft.com/en-us/azure/key-vault/general/developers-guide)
- [Azure Key Vault RBAC Guide](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
