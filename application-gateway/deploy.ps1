# Azure Application Gateway Deployment Script
# This script helps deploy the Application Gateway using Terraform

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('plan', 'apply', 'destroy', 'output')]
    [string]$Action = 'plan',
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

# Navigate to terraform directory
$terraformDir = Join-Path $PSScriptRoot "terraform"
Set-Location $terraformDir

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Azure Application Gateway Deployment" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed and authenticated
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if ($null -eq $account) {
        Write-Host "Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Authenticated as: $($account.user.name)" -ForegroundColor Green
    Write-Host "✓ Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
} catch {
    Write-Host "Error: Azure CLI not found or not authenticated." -ForegroundColor Red
    Write-Host "Please install Azure CLI and run 'az login'." -ForegroundColor Red
    exit 1
}

# Check if Terraform is installed
Write-Host "`nChecking Terraform installation..." -ForegroundColor Yellow
try {
    $tfVersion = terraform version
    Write-Host "✓ Terraform is installed: $($tfVersion[0])" -ForegroundColor Green
} catch {
    Write-Host "Error: Terraform not found. Please install Terraform." -ForegroundColor Red
    exit 1
}

# Initialize Terraform if needed
if (-not (Test-Path ".terraform")) {
    Write-Host "`nInitializing Terraform..." -ForegroundColor Yellow
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Terraform init failed." -ForegroundColor Red
        exit 1
    }
}

# Check if terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "`nWarning: terraform.tfvars not found." -ForegroundColor Yellow
    Write-Host "Using default values from variables.tf" -ForegroundColor Yellow
    Write-Host "To customize values, copy terraform.tfvars.example to terraform.tfvars" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue with default values? (y/n)"
    if ($continue -ne 'y') {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Execute the requested action
Write-Host "`nExecuting: terraform $Action" -ForegroundColor Yellow
Write-Host ""

switch ($Action) {
    'plan' {
        terraform plan
    }
    'apply' {
        if ($AutoApprove) {
            terraform apply -auto-approve
        } else {
            terraform apply
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n=====================================" -ForegroundColor Green
            Write-Host "Deployment Successful!" -ForegroundColor Green
            Write-Host "=====================================" -ForegroundColor Green
            Write-Host "`nRetrieving outputs..." -ForegroundColor Yellow
            terraform output
        }
    }
    'destroy' {
        Write-Host "WARNING: This will destroy all resources!" -ForegroundColor Red
        if ($AutoApprove) {
            terraform destroy -auto-approve
        } else {
            $confirm = Read-Host "Are you sure you want to destroy all resources? (yes/no)"
            if ($confirm -eq 'yes') {
                terraform destroy
            } else {
                Write-Host "Destroy cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    }
    'output' {
        terraform output
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nError: Terraform $Action failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nDone!" -ForegroundColor Green
