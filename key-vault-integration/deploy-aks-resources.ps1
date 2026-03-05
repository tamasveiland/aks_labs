# Get the workload identity client ID and Key Vault details
$WORKLOAD_IDENTITY_CLIENT_ID = terraform output -raw workload_identity_client_id
$KEY_VAULT_NAME = terraform output -raw key_vault_name
$KEY_VAULT_URI = terraform output -raw key_vault_uri

# Update the service account manifest
(Get-Content ../kubernetes/service-account.yaml) -replace '\$\{WORKLOAD_IDENTITY_CLIENT_ID\}', $WORKLOAD_IDENTITY_CLIENT_ID | kubectl apply -f -

# Update and apply the deployment
(Get-Content ../kubernetes/deployment.yaml) `
    -replace '\$\{KEY_VAULT_NAME\}', $KEY_VAULT_NAME `
    -replace '\$\{KEY_VAULT_URI\}', $KEY_VAULT_URI | kubectl apply -f -
