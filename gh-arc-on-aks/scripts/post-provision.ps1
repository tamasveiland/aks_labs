#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Post-provisioning script for GitHub Actions Runner Controller (ARC) on AKS.
    Installs the ARC Helm charts and configures a runner scale set.

.DESCRIPTION
    This script runs automatically after `azd provision`. It:
    1. Retrieves AKS credentials
    2. Installs the ARC controller via Helm
    3. Installs a runner scale set connected to your GitHub org/repo

.NOTES
    Requires: az CLI, kubectl, helm
    Environment variables are set automatically by azd from Bicep outputs.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Load azd environment variables into the current session
# ---------------------------------------------------------------------------
Write-Host "=== Loading azd environment variables ===" -ForegroundColor Cyan
azd env get-values | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $key = $Matches[1]
        $val = $Matches[2].Trim('"')
        Set-Item -Path "env:\$key" -Value $val
    }
}

# ---------------------------------------------------------------------------
# Read azd outputs (now available as environment variables)
# ---------------------------------------------------------------------------
$resourceGroup   = $env:AZURE_RESOURCE_GROUP
$clusterName     = $env:AZURE_AKS_CLUSTER_NAME
$githubConfigUrl = $env:GITHUB_CONFIG_URL
$githubPat       = $env:GITHUB_PAT   # Must be set by the user before running azd provision

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($resourceGroup) -or [string]::IsNullOrWhiteSpace($clusterName)) {
    Write-Error "Missing required environment variables AZURE_RESOURCE_GROUP and/or AZURE_AKS_CLUSTER_NAME. These should be set by azd."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($githubConfigUrl)) {
    Write-Warning "GITHUB_CONFIG_URL is not set. Skipping ARC runner scale set installation."
    Write-Warning "Set GITHUB_CONFIG_URL to your GitHub org or repo URL, then run: azd hooks run postprovision"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($githubPat)) {
    Write-Warning "GITHUB_PAT is not set. Skipping ARC runner scale set installation."
    Write-Warning "Create a GitHub PAT with the required scopes and set it:"
    Write-Warning "  azd env set GITHUB_PAT <your-pat>"
    Write-Warning "Then re-run: azd hooks run postprovision"
    exit 0
}

# ---------------------------------------------------------------------------
# 1. Get AKS credentials
# ---------------------------------------------------------------------------
Write-Host "`n=== Getting AKS credentials ===" -ForegroundColor Cyan
az aks get-credentials --resource-group $resourceGroup --name $clusterName --overwrite-existing
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to get AKS credentials"; exit 1 }

# ---------------------------------------------------------------------------
# 2. Add the ARC Helm repository
# ---------------------------------------------------------------------------
Write-Host "`n=== Adding ARC Helm repository ===" -ForegroundColor Cyan
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller 2>$null
helm repo update

# ---------------------------------------------------------------------------
# 3. Install the ARC controller (gha-runner-scale-set-controller)
# ---------------------------------------------------------------------------
$arcSystemNamespace = "arc-systems"
$arcRunnersNamespace = "arc-runners"

Write-Host "`n=== Installing ARC controller in namespace '$arcSystemNamespace' ===" -ForegroundColor Cyan

# Create namespaces if they don't exist
kubectl create namespace $arcSystemNamespace --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $arcRunnersNamespace --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install arc `
    --namespace $arcSystemNamespace `
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller `
    --wait

if ($LASTEXITCODE -ne 0) { Write-Error "Failed to install ARC controller"; exit 1 }
Write-Host "ARC controller installed successfully." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Install a runner scale set
# ---------------------------------------------------------------------------
Write-Host "`n=== Installing ARC runner scale set ===" -ForegroundColor Cyan


# Helm chart values reference:
# https://github.com/actions/actions-runner-controller/blob/master/charts/gha-runner-scale-set/values.yaml

helm upgrade --install arc-runner-set `
    --namespace $arcRunnersNamespace `
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set `
    --set githubConfigUrl="$githubConfigUrl" `
    --set githubConfigSecret.github_token="$githubPat" `
    --set "template.spec.tolerations[0].key=github-runner" `
    --set "template.spec.tolerations[0].operator=Equal" `
    --set-string "template.spec.tolerations[0].value=true" `
    --set "template.spec.tolerations[0].effect=NoSchedule" `
    --set-string "template.spec.nodeSelector.github-runner=true" `
    --set maxRunners=5 `
    --set minRunners=0 `
    --wait

if ($LASTEXITCODE -ne 0) { Write-Error "Failed to install ARC runner scale set"; exit 1 }
Write-Host "ARC runner scale set installed successfully." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Verify installation
# ---------------------------------------------------------------------------
Write-Host "`n=== Verifying ARC installation ===" -ForegroundColor Cyan
Write-Host "`nPods in $arcSystemNamespace namespace:" -ForegroundColor Yellow
kubectl get pods -n $arcSystemNamespace

Write-Host "`nPods in $arcRunnersNamespace namespace:" -ForegroundColor Yellow
kubectl get pods -n $arcRunnersNamespace

Write-Host "`n=== Post-provisioning complete ===" -ForegroundColor Green
Write-Host "Your self-hosted runners will appear in GitHub under:"
Write-Host "  $githubConfigUrl/settings/actions/runners"
Write-Host ""
Write-Host "To use these runners in a workflow, set:"
Write-Host '  runs-on: arc-runner-set'
Write-Host ""
