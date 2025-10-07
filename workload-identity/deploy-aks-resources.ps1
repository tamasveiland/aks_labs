# Get the workload identity client ID and storage account name
$WORKLOAD_IDENTITY_CLIENT_ID = terraform output -raw workload_identity_client_id
$STORAGE_ACCOUNT_NAME = terraform output -raw storage_account_name

# Update the service account manifest
(Get-Content ./kubernetes/service-account.yaml) -replace '\$\{WORKLOAD_IDENTITY_CLIENT_ID\}', $WORKLOAD_IDENTITY_CLIENT_ID | kubectl apply -f -

# Update and apply the deployment
(Get-Content ./kubernetes/deployment.yaml) -replace '\$\{STORAGE_ACCOUNT_NAME\}', $STORAGE_ACCOUNT_NAME | kubectl apply -f -