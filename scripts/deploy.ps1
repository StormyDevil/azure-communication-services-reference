#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys the Azure Communication Services reference architecture.

.DESCRIPTION
    This script deploys the ACS enterprise reference architecture to Azure,
    following CAF/WAF best practices. It performs validation, what-if analysis,
    and deployment with proper error handling.

.PARAMETER Environment
    Target environment (dev, staging, prod).

.PARAMETER Location
    Azure region for deployment. Location-agnostic by default.

.PARAMETER ResourceGroupName
    Optional custom resource group name. Defaults to rg-acs-{environment}.

.PARAMETER SubscriptionId
    Optional Azure subscription ID. If not provided, allows interactive selection.

.PARAMETER SkipValidation
    Skip Bicep validation and what-if analysis.

.EXAMPLE
    ./deploy.ps1 -Environment dev -Location swedencentral

.EXAMPLE
    ./deploy.ps1 -Environment prod -Location westeurope -ResourceGroupName rg-acs-production

.EXAMPLE
    ./deploy.ps1 -Environment dev -SubscriptionId "12345678-1234-1234-1234-123456789012"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'swedencentral',

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [switch]$SkipApplication,

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# Configuration
# ============================================================================

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraPath = Join-Path (Join-Path (Join-Path $ScriptPath '..') 'infra') 'bicep'
$MainBicep = Join-Path $InfraPath 'main.bicep'
$ParameterFile = Join-Path (Join-Path $InfraPath 'parameters') "$Environment.bicepparam"

# Default resource group name
if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-acs-$Environment"
}

$DeploymentName = "acs-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Banner {
    param([string]$Message)
    Write-Host ""
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "=========================================================================" -ForegroundColor Cyan
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
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [i] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "  [X] " -ForegroundColor Red -NoNewline
    Write-Host $Message -ForegroundColor Red
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-Banner "Azure Communication Services - Deployment"

Write-Host "  -------------------------------------------------------------------------"
Write-Host "  DEPLOYMENT CONFIGURATION"
Write-Host "  -------------------------------------------------------------------------"
Write-Host ""
Write-Host "      Environment:      $Environment" -ForegroundColor White
Write-Host "      Location:         $Location" -ForegroundColor White
Write-Host "      Resource Group:   $ResourceGroupName" -ForegroundColor White
Write-Host "      Deploy App:       $(if ($SkipApplication) { 'No (infrastructure only)' } else { 'Yes' })" -ForegroundColor $(if ($SkipApplication) { 'Yellow' } else { 'White' })
Write-Host "      Template:         $MainBicep" -ForegroundColor White
Write-Host "      Parameters:       $ParameterFile" -ForegroundColor White
Write-Host ""

# Check prerequisites
Write-Step 1 5 "Checking prerequisites..."

# Check Azure CLI
$azVersion = az version 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $azVersion) {
    Write-ErrorMsg "Azure CLI not found. Please install from https://aka.ms/azure-cli"
    exit 1
}
Write-Success "Azure CLI v$($azVersion.'azure-cli') detected"

# Check Bicep CLI (via Azure CLI)
$bicepVersion = az bicep version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Info "Bicep CLI not found. Installing via Azure CLI..."
    az bicep install
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to install Bicep CLI"
        exit 1
    }
}
Write-Success "Bicep CLI detected"

# Check Azure login
$account = az account show 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $account) {
    Write-Info "Not logged in to Azure. Initiating login..."
    az login
    $account = az account show | ConvertFrom-Json
}
Write-Success "Logged in as $($account.user.name)"

# Subscription selection
if ($SubscriptionId) {
    # Use provided subscription ID
    Write-Info "Setting subscription to: $SubscriptionId"
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to set subscription: $SubscriptionId"
        exit 1
    }
    $account = az account show | ConvertFrom-Json
    Write-Success "Subscription set to: $($account.name)"
}
else {
    # List available subscriptions and allow selection
    $subscriptions = az account list --query "[].{name:name, id:id, isDefault:isDefault}" 2>&1 | ConvertFrom-Json
    
    if ($subscriptions.Count -gt 1) {
        Write-Host ""
        Write-Host "  -------------------------------------------------------------------------"
        Write-Host "  AVAILABLE SUBSCRIPTIONS"
        Write-Host "  -------------------------------------------------------------------------"
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
                    Write-ErrorMsg "Failed to set subscription"
                    exit 1
                }
                $account = az account show | ConvertFrom-Json
                Write-Success "Switched to subscription: $($account.name)"
            }
            else {
                Write-ErrorMsg "Invalid selection"
                exit 1
            }
        }
        else {
            Write-Info "Using current subscription"
        }
        Write-Host ""
    }
}

Write-Host "      -> Subscription: $($account.name)" -ForegroundColor Gray
Write-Host "      -> Subscription ID: $($account.id)" -ForegroundColor Gray

# Location selection (if default location is used)
if ($Location -eq 'swedencentral') {
    Write-Host ""
    Write-Host "  -------------------------------------------------------------------------"
    Write-Host "  SELECT DEPLOYMENT REGION (ACS Supported Data Locations)"
    Write-Host "  -------------------------------------------------------------------------"
    Write-Host ""
    
    $regions = @(
        @{ Name = 'unitedstates'; Description = 'United States'; Category = 'Americas' }
        @{ Name = 'brazilsouth'; Description = 'Brazil South (Sao Paulo)'; Category = 'Americas' }
        @{ Name = 'canadacentral'; Description = 'Canada Central (Toronto)'; Category = 'Americas' }
        @{ Name = 'europe'; Description = 'Europe (Default)'; Category = 'Europe' }
        @{ Name = 'francecentral'; Description = 'France Central (Paris)'; Category = 'Europe' }
        @{ Name = 'germanywestcentral'; Description = 'Germany West Central (Frankfurt)'; Category = 'Europe' }
        @{ Name = 'northeurope'; Description = 'North Europe (Ireland)'; Category = 'Europe' }
        @{ Name = 'norwayeast'; Description = 'Norway East (Oslo)'; Category = 'Europe' }
        @{ Name = 'swedencentral'; Description = 'Sweden Central (Gavle)'; Category = 'Europe' }
        @{ Name = 'switzerlandnorth'; Description = 'Switzerland North (Zurich)'; Category = 'Europe' }
        @{ Name = 'uksouth'; Description = 'UK South (London)'; Category = 'Europe' }
        @{ Name = 'westeurope'; Description = 'West Europe (Netherlands)'; Category = 'Europe' }
        @{ Name = 'asia'; Description = 'Asia Pacific'; Category = 'Asia' }
        @{ Name = 'australiaeast'; Description = 'Australia East (Sydney)'; Category = 'Asia' }
        @{ Name = 'centralindia'; Description = 'Central India (Pune)'; Category = 'Asia' }
        @{ Name = 'japaneast'; Description = 'Japan East (Tokyo)'; Category = 'Asia' }
        @{ Name = 'japanwest'; Description = 'Japan West (Osaka)'; Category = 'Asia' }
        @{ Name = 'koreacentral'; Description = 'Korea Central (Seoul)'; Category = 'Asia' }
        @{ Name = 'southeastasia'; Description = 'Southeast Asia (Singapore)'; Category = 'Asia' }
        @{ Name = 'southafricanorth'; Description = 'South Africa North (Johannesburg)'; Category = 'MEA' }
        @{ Name = 'uaenorth'; Description = 'UAE North (Dubai)'; Category = 'MEA' }
    )
    
    $currentCategory = ''
    for ($i = 0; $i -lt $regions.Count; $i++) {
        $region = $regions[$i]
        if ($region.Category -ne $currentCategory) {
            $currentCategory = $region.Category
            Write-Host ""
            $categoryHeader = switch ($currentCategory) {
                'Americas' { '  Americas:' }
                'Europe' { '  Europe:' }
                'Asia' { '  Asia Pacific:' }
                'MEA' { '  Middle East and Africa:' }
            }
            Write-Host $categoryHeader -ForegroundColor Cyan
        }
        $marker = if ($region.Name -eq 'europe') { " (recommended)" } else { "" }
        $color = if ($region.Name -eq 'europe') { "Green" } else { "White" }
        Write-Host "      [$($i + 1)] $($region.Description)$marker" -ForegroundColor $color
    }
    Write-Host ""
    
    $regionSelection = Read-Host "  Select region [1-$($regions.Count)] or press Enter for Europe (default)"
    
    if ($regionSelection -and $regionSelection -match '^\d+$') {
        $index = [int]$regionSelection - 1
        if ($index -ge 0 -and $index -lt $regions.Count) {
            $Location = $regions[$index].Name
            Write-Success "Selected region: $($regions[$index].Description) ($Location)"
        }
        else {
            Write-ErrorMsg "Invalid selection"
            exit 1
        }
    }
    else {
        $Location = 'europe'
        Write-Info "Using default: Europe"
    }
    Write-Host ""
}
else {
    Write-Info "Using specified region: $Location"
}

Write-Host "      -> Deployment Region: $Location" -ForegroundColor Gray
Write-Host ""

# Check files exist
if (-not (Test-Path $MainBicep)) {
    Write-ErrorMsg "Main Bicep template not found: $MainBicep"
    exit 1
}
if (-not (Test-Path $ParameterFile)) {
    Write-ErrorMsg "Parameter file not found: $ParameterFile"
    exit 1
}
Write-Success "Template and parameter files found"

# ============================================================================
# Validation
# ============================================================================

if (-not $SkipValidation) {
    Write-Step 2 5 "Validating Bicep templates..."
    
    # Bicep build
    Write-Host "      -> Running bicep build..." -ForegroundColor Gray
    $buildOutput = az bicep build --file $MainBicep 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Bicep build failed:"
        Write-Host $buildOutput -ForegroundColor Red
        exit 1
    }
    Write-Success "Bicep build successful"
    
    # Bicep lint
    Write-Host "      -> Running bicep lint..." -ForegroundColor Gray
    $lintOutput = az bicep lint --file $MainBicep 2>&1
    if ($lintOutput -match "Error") {
        Write-ErrorMsg "Bicep lint found errors:"
        Write-Host $lintOutput -ForegroundColor Red
        exit 1
    }
    Write-Success "Bicep lint passed"
}
else {
    Write-Step 2 5 "Skipping validation (--SkipValidation specified)"
}

# ============================================================================
# Resource Group
# ============================================================================

Write-Step 3 5 "Ensuring resource group exists..."

$rgExists = az group show --name $ResourceGroupName 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $rgExists) {
    Write-Info "Creating resource group: $ResourceGroupName"
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create resource group")) {
        az group create --name $ResourceGroupName --location $Location --tags Environment=$Environment ManagedBy=Bicep | Out-Null
        Write-Success "Resource group created"
    }
}
else {
    Write-Success "Resource group already exists"
}

# ============================================================================
# What-If Analysis
# ============================================================================

Write-Step 4 5 "Running what-if analysis..."

$deployApp = if ($SkipApplication) { 'false' } else { 'true' }

$whatIfResult = az deployment group what-if `
    --name $DeploymentName `
    --resource-group $ResourceGroupName `
    --template-file $MainBicep `
    --parameters $ParameterFile `
    --parameters location=$Location `
    --parameters deployApplication=$deployApp `
    --no-pretty-print 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "What-if analysis failed"
    Write-Host $whatIfResult -ForegroundColor Red
    exit 1
}

# Parse what-if results
$whatIfText = $whatIfResult -join "`n"
$createCount = ([regex]::Matches($whatIfText, "Create")).Count
$modifyCount = ([regex]::Matches($whatIfText, "Modify")).Count
$deleteCount = ([regex]::Matches($whatIfText, "Delete")).Count
$noChangeCount = ([regex]::Matches($whatIfText, "NoChange")).Count

Write-Host ""
Write-Host "  -------------------------------------------------------------------------"
Write-Host "  CHANGE SUMMARY"
Write-Host "  -------------------------------------------------------------------------"
Write-Host ""
Write-Host "      + Create:    $createCount resources" -ForegroundColor Green
Write-Host "      ~ Modify:    $modifyCount resources" -ForegroundColor Yellow
Write-Host "      - Delete:    $deleteCount resources" -ForegroundColor Red
Write-Host "      = No Change: $noChangeCount resources" -ForegroundColor Gray
Write-Host ""

# Confirmation
if (-not $WhatIfPreference) {
    $confirmation = Read-Host "  Do you want to proceed with deployment? (yes/no)"
    if ($confirmation -ne 'yes') {
        Write-Info "Deployment cancelled by user"
        exit 0
    }
}

# ============================================================================
# Deployment
# ============================================================================

Write-Step 5 5 "Deploying resources..."

if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy ACS infrastructure")) {
    $startTime = Get-Date
    
    $deploymentResult = az deployment group create `
        --name $DeploymentName `
        --resource-group $ResourceGroupName `
        --template-file $MainBicep `
        --parameters $ParameterFile `
        --parameters location=$Location `
        --parameters deployApplication=$deployApp `
        --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Deployment failed"
        Write-Host $deploymentResult -ForegroundColor Red
        exit 1
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Success "Deployment completed in $([math]::Round($duration.TotalMinutes, 2)) minutes"
    
    # Parse outputs
    $deployment = $deploymentResult | ConvertFrom-Json
    $outputs = $deployment.properties.outputs
    
    Write-Host ""
    Write-Host "  -------------------------------------------------------------------------"
    Write-Host "  DEPLOYMENT OUTPUTS"
    Write-Host "  -------------------------------------------------------------------------"
    Write-Host ""
    Write-Host "      ACS Endpoint:        $($outputs.acsEndpoint.value)" -ForegroundColor Cyan
    Write-Host "      App Service URL:     $($outputs.appServiceUrl.value)" -ForegroundColor Cyan
    Write-Host "      Function App URL:    $($outputs.functionAppUrl.value)" -ForegroundColor Cyan
    Write-Host "      Key Vault:           $($outputs.keyVaultName.value)" -ForegroundColor Cyan
    Write-Host "      Resource Group:      $($outputs.resourceGroupName.value)" -ForegroundColor Cyan
    Write-Host ""
    
    # Portal link
    $portalUrl = "https://portal.azure.com/#@/resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/overview"
    Write-Host "  Azure Portal: $portalUrl" -ForegroundColor Blue
    Write-Host ""
}

Write-Banner "Deployment Complete!"
