#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleans up Azure Communication Services resources.

.DESCRIPTION
    This script removes all resources deployed by the ACS reference architecture.
    It can either delete the entire resource group or selectively remove resources.

.PARAMETER Environment
    Target environment (dev, staging, prod).

.PARAMETER ResourceGroupName
    Optional custom resource group name. Defaults to rg-acs-{environment}.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER SubscriptionId
    Optional Azure subscription ID. If not provided, allows interactive selection.

.PARAMETER KeepResourceGroup
    Keep the resource group but delete all resources within it.

.EXAMPLE
    ./cleanup.ps1 -Environment dev

.EXAMPLE
    ./cleanup.ps1 -Environment prod -Force

.EXAMPLE
    ./cleanup.ps1 -Environment dev -SubscriptionId "12345678-1234-1234-1234-123456789012"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [switch]$KeepResourceGroup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# Configuration
# ============================================================================

if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-acs-$Environment"
}

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Banner {
    param([string]$Message)
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  $($Message.PadRight(69))║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

function Write-Step {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Message
    )
    Write-Host "  [$Step/$Total] " -ForegroundColor DarkGray -NoNewline
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  ⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message -ForegroundColor Yellow
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-Banner "Azure Communication Services - Cleanup"

Write-Host "  ┌────────────────────────────────────────────────────────────────────┐"
Write-Host "  │  ⚠  WARNING: DESTRUCTIVE OPERATION                                 │"
Write-Host "  └────────────────────────────────────────────────────────────────────┘"
Write-Host ""
Write-Host "      Environment:      $Environment" -ForegroundColor White
Write-Host "      Resource Group:   $ResourceGroupName" -ForegroundColor White
Write-Host "      Keep RG:          $KeepResourceGroup" -ForegroundColor White
Write-Host ""

# Check Azure login
Write-Step 1 3 "Checking Azure login..."

$account = az account show 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $account) {
    Write-Info "Not logged in to Azure. Initiating login..."
    az login
    $account = az account show | ConvertFrom-Json
}
Write-Success "Logged in as $($account.user.name)"

# Subscription selection
if ($SubscriptionId) {
    Write-Info "Setting subscription to: $SubscriptionId"
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to set subscription: $SubscriptionId"
        exit 1
    }
    $account = az account show | ConvertFrom-Json
    Write-Success "Subscription set to: $($account.name)"
}
else {
    $subscriptions = az account list --query "[].{name:name, id:id, isDefault:isDefault}" 2>&1 | ConvertFrom-Json
    
    if ($subscriptions.Count -gt 1) {
        Write-Host ""
        Write-Host "  ┌────────────────────────────────────────────────────────────────────┐"
        Write-Host "  │  AVAILABLE SUBSCRIPTIONS                                           │"
        Write-Host "  └────────────────────────────────────────────────────────────────────┘"
        Write-Host ""
        
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            $sub = $subscriptions[$i]
            $marker = if ($sub.isDefault) { " (current)" } else { "" }
            $color = if ($sub.isDefault) { "Green" } else { "White" }
            Write-Host "      [$($i + 1)] $($sub.name)$marker" -ForegroundColor $color
            Write-Host "          $($sub.id)" -ForegroundColor Gray
        }
        Write-Host ""
        
        $selection = Read-Host "  Select subscription [1-$($subscriptions.Count)] or press Enter for current"
        
        if ($selection -and $selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $subscriptions.Count) {
                $selectedSub = $subscriptions[$index]
                az account set --subscription $selectedSub.id
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to set subscription"
                    exit 1
                }
                $account = az account show | ConvertFrom-Json
                Write-Success "Switched to subscription: $($account.name)"
            }
            else {
                Write-Warning "Invalid selection"
                exit 1
            }
        }
        else {
            Write-Info "Using current subscription"
        }
        Write-Host ""
    }
}
Write-Host "      └─ Subscription: $($account.name)" -ForegroundColor Gray
Write-Host "      └─ Subscription ID: $($account.id)" -ForegroundColor Gray

# Check resource group exists
Write-Step 2 3 "Checking resource group..."

$rgExists = az group show --name $ResourceGroupName 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $rgExists) {
    Write-Warning "Resource group '$ResourceGroupName' does not exist"
    exit 0
}

# List resources
$resources = az resource list --resource-group $ResourceGroupName 2>&1 | ConvertFrom-Json
$resourceCount = $resources.Count

Write-Success "Found $resourceCount resources in resource group"
Write-Host ""

if ($resourceCount -gt 0) {
    Write-Host "  Resources to be deleted:" -ForegroundColor Yellow
    foreach ($resource in $resources) {
        Write-Host "      - $($resource.type): $($resource.name)" -ForegroundColor Gray
    }
    Write-Host ""
}

# ============================================================================
# Confirmation
# ============================================================================

if (-not $Force) {
    Write-Warning "This action will permanently delete all resources!"
    Write-Host ""
    
    if ($KeepResourceGroup) {
        $confirmText = "Type 'DELETE RESOURCES' to confirm"
        $expectedInput = "DELETE RESOURCES"
    }
    else {
        $confirmText = "Type 'DELETE $ResourceGroupName' to confirm"
        $expectedInput = "DELETE $ResourceGroupName"
    }
    
    $confirmation = Read-Host "  $confirmText"
    if ($confirmation -ne $expectedInput) {
        Write-Info "Cleanup cancelled by user"
        exit 0
    }
}

# ============================================================================
# Cleanup
# ============================================================================

Write-Step 3 3 "Deleting resources..."

if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Delete resources")) {
    $startTime = Get-Date
    
    if ($KeepResourceGroup) {
        # Delete resources individually
        Write-Info "Deleting resources while keeping resource group..."
        
        # Delete in dependency order (reverse of creation)
        $resourceTypes = @(
            'Microsoft.EventGrid/systemTopics',
            'Microsoft.Web/sites',
            'Microsoft.Web/serverfarms',
            'Microsoft.DocumentDB/databaseAccounts',
            'Microsoft.Communication/communicationServices',
            'Microsoft.KeyVault/vaults',
            'Microsoft.Storage/storageAccounts',
            'Microsoft.Insights/components',
            'Microsoft.OperationalInsights/workspaces'
        )
        
        foreach ($type in $resourceTypes) {
            $typeResources = $resources | Where-Object { $_.type -eq $type }
            foreach ($resource in $typeResources) {
                Write-Host "      └─ Deleting $($resource.name)..." -ForegroundColor Gray
                az resource delete --ids $resource.id --verbose 2>&1 | Out-Null
            }
        }
        
        Write-Success "All resources deleted"
    }
    else {
        # Delete entire resource group
        Write-Info "Deleting resource group and all resources..."
        az group delete --name $ResourceGroupName --yes --no-wait
        
        Write-Info "Resource group deletion initiated (running in background)"
        Write-Info "Check Azure Portal for deletion status"
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Success "Cleanup initiated in $([math]::Round($duration.TotalSeconds, 2)) seconds"
}

Write-Host ""
Write-Host "  ┌────────────────────────────────────────────────────────────────────┐"
Write-Host "  │  Cleanup Complete                                                   │"
Write-Host "  └────────────────────────────────────────────────────────────────────┘"
Write-Host ""

if (-not $KeepResourceGroup) {
    Write-Info "Resource group deletion runs asynchronously"
    Write-Info "Monitor progress in Azure Portal or run:"
    Write-Host "      az group show --name $ResourceGroupName" -ForegroundColor Cyan
}
