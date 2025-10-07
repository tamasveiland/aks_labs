#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AKS Workload Identity Lab - Quick Start${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites are installed${NC}"
echo ""

# Navigate to terraform directory
cd "$(dirname "$0")/terraform"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}Please edit terraform.tfvars and update the values, especially storage_account_name${NC}"
    echo -e "${RED}Then run this script again.${NC}"
    exit 1
fi

# Terraform init
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Terraform plan
echo -e "${YELLOW}Planning Terraform deployment...${NC}"
terraform plan -out=tfplan

# Ask for confirmation
echo ""
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 0
fi

# Terraform apply
echo -e "${YELLOW}Applying Terraform configuration...${NC}"
terraform apply tfplan

# Get outputs
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}Getting Terraform outputs...${NC}"
WORKLOAD_IDENTITY_CLIENT_ID=$(terraform output -raw workload_identity_client_id)
STORAGE_ACCOUNT_NAME=$(terraform output -raw storage_account_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_NAME=$(terraform output -raw aks_cluster_name)

echo "Workload Identity Client ID: $WORKLOAD_IDENTITY_CLIENT_ID"
echo "Storage Account Name: $STORAGE_ACCOUNT_NAME"
echo ""

# Get AKS credentials
echo -e "${YELLOW}Getting AKS credentials...${NC}"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing

# Deploy Kubernetes resources
echo -e "${YELLOW}Deploying Kubernetes resources...${NC}"
cd ../kubernetes

# Apply service account
sed "s/\${WORKLOAD_IDENTITY_CLIENT_ID}/$WORKLOAD_IDENTITY_CLIENT_ID/g" service-account.yaml | kubectl apply -f -

# Apply deployment
sed "s/\${STORAGE_ACCOUNT_NAME}/$STORAGE_ACCOUNT_NAME/g" deployment.yaml | kubectl apply -f -

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "You can check the pod logs with:"
echo "  kubectl get pods"
echo "  kubectl logs deployment/workload-identity-demo"
echo ""
echo "To cleanup, run:"
echo "  cd terraform && terraform destroy"
