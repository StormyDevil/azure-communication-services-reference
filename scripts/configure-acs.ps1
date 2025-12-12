<#
.SYNOPSIS
    Configures Azure Communication Services after infrastructure deployment.

.DESCRIPTION
    This script configures ACS resources post-deployment including:
    - Phone number acquisition (toll-free or geographic)
    - Email domain configuration
    - Creating test identities and access tokens
    - Event Grid subscription setup (after function code deployment)
    - SMS webhook configuration

.PARAMETER ResourceGroupName
    The name of the resource group containing ACS resources.

.PARAMETER AcsResourceName
    The name of the Azure Communication Services resource.

.PARAMETER ConfigFile
    Path to the JSON configuration file. Defaults to ./acs-config.json

.PARAMETER Action
    The configuration action to perform:
    - All: Run all configuration steps
    - PhoneNumbers: Acquire phone numbers only
    - Email: Configure email domain only
    - Identity: Create test identities only
    - EventGrid: Setup Event Grid subscriptions only
    - Status: Show current configuration status

.EXAMPLE
    ./configure-acs.ps1 -ResourceGroupName "rg-acs-dev" -AcsResourceName "acs-acsref-dev" -Action Status

.EXAMPLE
    ./configure-acs.ps1 -ResourceGroupName "rg-acs-dev" -AcsResourceName "acs-acsref-dev" -Action Identity

.NOTES
    Author: Agentic InfraOps
    Requires: Azure CLI, Az.Communication module (optional)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-acs-dev",

    [Parameter(Mandatory = $false)]
    [string]$AcsResourceName,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "./acs-config.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "PhoneNumbers", "Email", "Identity", "EventGrid", "Status")]
    [string]$Action = "Status"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Banner {
    Write-Host @"

    ╔═══════════════════════════════════════════════════════════════════════╗
    ║   Azure Communication Services - Post-Deployment Configuration       ║
    ╚═══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
}

function Write-Section {
    param([string]$Title)
    Write-Host "`n  ┌────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  $($Title.PadRight(66)) │" -ForegroundColor Yellow
    Write-Host "  └────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Success", "Warning", "Error", "Info")]
        [string]$Type = "Info"
    )
    
    $icon = switch ($Type) {
        "Success" { "✓"; $color = "Green" }
        "Warning" { "⚠"; $color = "Yellow" }
        "Error"   { "✗"; $color = "Red" }
        "Info"    { "→"; $color = "Cyan" }
    }
    
    Write-Host "  $icon " -ForegroundColor $color -NoNewline
    Write-Host $Message
}

function Get-AcsConnectionString {
    param([string]$ResourceGroup, [string]$ResourceName)
    
    $keys = az communication list-key `
        --name $ResourceName `
        --resource-group $ResourceGroup `
        --query "primaryConnectionString" `
        --output tsv 2>$null
    
    return $keys
}

# ============================================================================
# Configuration Functions
# ============================================================================

function Get-AcsStatus {
    param([string]$ResourceGroup, [string]$ResourceName)
    
    Write-Section "ACS Resource Status"
    
    # Get ACS resource details
    $acsResource = az communication show `
        --name $ResourceName `
        --resource-group $ResourceGroup `
        --output json 2>$null | ConvertFrom-Json
    
    if (-not $acsResource) {
        Write-Status "ACS resource '$ResourceName' not found in '$ResourceGroup'" -Type Error
        return $false
    }
    
    Write-Status "Resource Name: $($acsResource.name)" -Type Success
    Write-Status "Data Location: $($acsResource.dataLocation)" -Type Info
    Write-Status "Provisioning State: $($acsResource.provisioningState)" -Type Info
    Write-Status "Host Name: $($acsResource.hostName)" -Type Info
    
    # Check for phone numbers
    Write-Host ""
    Write-Status "Checking phone numbers..." -Type Info
    $phoneNumbers = az communication phonenumber list `
        --connection-string (Get-AcsConnectionString -ResourceGroup $ResourceGroup -ResourceName $ResourceName) `
        --output json 2>$null | ConvertFrom-Json
    
    if ($phoneNumbers -and $phoneNumbers.Count -gt 0) {
        Write-Status "Phone numbers configured: $($phoneNumbers.Count)" -Type Success
        foreach ($number in $phoneNumbers) {
            Write-Host "      └─ $($number.phoneNumber) ($($number.phoneNumberType))" -ForegroundColor Gray
        }
    } else {
        Write-Status "No phone numbers configured" -Type Warning
    }
    
    # Check for email domains
    Write-Host ""
    Write-Status "Checking email domains..." -Type Info
    $emailDomains = az communication email domain list `
        --resource-group $ResourceGroup `
        --output json 2>$null | ConvertFrom-Json
    
    if ($emailDomains -and $emailDomains.Count -gt 0) {
        Write-Status "Email domains configured: $($emailDomains.Count)" -Type Success
    } else {
        Write-Status "No email domains configured (Email capability not enabled)" -Type Warning
    }
    
    return $true
}

function New-AcsIdentity {
    param([string]$ResourceGroup, [string]$ResourceName)
    
    Write-Section "Creating Test Identity"
    
    $connectionString = Get-AcsConnectionString -ResourceGroup $ResourceGroup -ResourceName $ResourceName
    
    if (-not $connectionString) {
        Write-Status "Could not retrieve ACS connection string" -Type Error
        return $null
    }
    
    # Create identity using REST API via Azure CLI
    Write-Status "Creating new communication identity..." -Type Info
    
    $identity = az communication identity create `
        --connection-string $connectionString `
        --scopes "chat" "voip" `
        --output json 2>$null | ConvertFrom-Json
    
    if ($identity) {
        Write-Status "Identity created successfully" -Type Success
        Write-Host "      └─ Identity ID: $($identity.identity.id)" -ForegroundColor Gray
        Write-Host "      └─ Token expires: $($identity.accessToken.expiresOn)" -ForegroundColor Gray
        
        # Save to config file
        $configOutput = @{
            identity = @{
                id = $identity.identity.id
                createdAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }
            accessToken = @{
                token = $identity.accessToken.token
                expiresOn = $identity.accessToken.expiresOn
            }
        }
        
        $configOutput | ConvertTo-Json -Depth 5 | Out-File -FilePath "./acs-identity.json" -Encoding utf8
        Write-Status "Identity saved to ./acs-identity.json" -Type Success
        
        return $identity
    } else {
        Write-Status "Failed to create identity" -Type Error
        return $null
    }
}

function Get-AvailablePhoneNumbers {
    param(
        [string]$ResourceGroup,
        [string]$ResourceName,
        [string]$CountryCode = "US",
        [string]$PhoneNumberType = "tollFree"
    )
    
    Write-Section "Searching Available Phone Numbers"
    
    $connectionString = Get-AcsConnectionString -ResourceGroup $ResourceGroup -ResourceName $ResourceName
    
    Write-Status "Searching for $PhoneNumberType numbers in $CountryCode..." -Type Info
    
    # Search for available numbers
    $searchResult = az communication phonenumber search `
        --connection-string $connectionString `
        --country-code $CountryCode `
        --phone-number-type $PhoneNumberType `
        --assignment-type "application" `
        --capabilities "inbound" "outbound" `
        --quantity 1 `
        --output json 2>$null | ConvertFrom-Json
    
    if ($searchResult -and $searchResult.phoneNumbers) {
        Write-Status "Found available numbers:" -Type Success
        foreach ($number in $searchResult.phoneNumbers) {
            Write-Host "      └─ $number" -ForegroundColor Green
        }
        Write-Host ""
        Write-Status "Search ID: $($searchResult.searchId)" -Type Info
        Write-Status "To purchase, use: az communication phonenumber purchase --search-id $($searchResult.searchId)" -Type Info
        
        return $searchResult
    } else {
        Write-Status "No phone numbers available in this region/type" -Type Warning
        Write-Status "Try different country code or phone number type" -Type Info
        return $null
    }
}

function Set-EventGridSubscriptions {
    param(
        [string]$ResourceGroup,
        [string]$ResourceName,
        [string]$FunctionAppName
    )
    
    Write-Section "Configuring Event Grid Subscriptions"
    
    # Get ACS resource ID
    $acsResource = az communication show `
        --name $ResourceName `
        --resource-group $ResourceGroup `
        --query "id" `
        --output tsv 2>$null
    
    if (-not $acsResource) {
        Write-Status "ACS resource not found" -Type Error
        return $false
    }
    
    # Check if function app exists and has deployed functions
    Write-Status "Checking Function App '$FunctionAppName'..." -Type Info
    
    $functions = az functionapp function list `
        --name $FunctionAppName `
        --resource-group $ResourceGroup `
        --output json 2>$null | ConvertFrom-Json
    
    if (-not $functions -or $functions.Count -eq 0) {
        Write-Status "No functions deployed to '$FunctionAppName'" -Type Warning
        Write-Status "Deploy function code first, then run this script again" -Type Info
        return $false
    }
    
    Write-Status "Found $($functions.Count) deployed functions" -Type Success
    
    # Get system topic name
    $systemTopicName = "evgt-$($ResourceName -replace 'acs-', '')"
    
    # Create event subscriptions for each function
    $eventSubscriptions = @(
        @{
            Name = "sms-received-subscription"
            EventTypes = @("Microsoft.Communication.SMSReceived")
            FunctionName = "process_sms_received"
        },
        @{
            Name = "chat-events-subscription"
            EventTypes = @("Microsoft.Communication.ChatMessageReceived", "Microsoft.Communication.ChatThreadCreated")
            FunctionName = "process_chat_event"
        },
        @{
            Name = "recording-events-subscription"
            EventTypes = @("Microsoft.Communication.RecordingFileStatusUpdated")
            FunctionName = "process_recording_event"
        }
    )
    
    foreach ($subscription in $eventSubscriptions) {
        $functionExists = $functions | Where-Object { $_.name -eq $subscription.FunctionName }
        
        if ($functionExists) {
            Write-Status "Creating subscription '$($subscription.Name)'..." -Type Info
            
            $functionId = "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$FunctionAppName/functions/$($subscription.FunctionName)"
            
            az eventgrid system-topic event-subscription create `
                --name $subscription.Name `
                --system-topic-name $systemTopicName `
                --resource-group $ResourceGroup `
                --endpoint-type "azurefunction" `
                --endpoint $functionId `
                --included-event-types $subscription.EventTypes `
                --output none 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Status "Created: $($subscription.Name)" -Type Success
            } else {
                Write-Status "Failed to create: $($subscription.Name)" -Type Error
            }
        } else {
            Write-Status "Function '$($subscription.FunctionName)' not deployed - skipping" -Type Warning
        }
    }
    
    return $true
}

function Show-ConfigurationSummary {
    param([string]$ResourceGroup, [string]$ResourceName)
    
    Write-Section "Configuration Summary"
    
    Write-Host @"

  Available Configuration Actions:
  ─────────────────────────────────────────────────────────────────────────
  
  1. Status        - View current ACS configuration
                     ./configure-acs.ps1 -Action Status
  
  2. Identity      - Create a test user identity with access token
                     ./configure-acs.ps1 -Action Identity
  
  3. PhoneNumbers  - Search for available phone numbers
                     ./configure-acs.ps1 -Action PhoneNumbers
  
  4. EventGrid     - Configure Event Grid subscriptions (after code deploy)
                     ./configure-acs.ps1 -Action EventGrid
  
  5. All           - Run all configuration steps
                     ./configure-acs.ps1 -Action All

  ─────────────────────────────────────────────────────────────────────────

"@ -ForegroundColor Gray

    Write-Status "Resource Group: $ResourceGroup" -Type Info
    Write-Status "ACS Resource: $ResourceName" -Type Info
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Banner

# Auto-detect ACS resource name if not provided
if (-not $AcsResourceName) {
    Write-Status "Auto-detecting ACS resource in '$ResourceGroupName'..." -Type Info
    $acsResources = az communication list `
        --resource-group $ResourceGroupName `
        --query "[].name" `
        --output json 2>$null | ConvertFrom-Json
    
    if ($acsResources -and $acsResources.Count -gt 0) {
        $AcsResourceName = $acsResources[0]
        Write-Status "Found: $AcsResourceName" -Type Success
    } else {
        Write-Status "No ACS resources found in '$ResourceGroupName'" -Type Error
        Write-Status "Please specify -AcsResourceName parameter" -Type Info
        exit 1
    }
}

# Execute requested action
switch ($Action) {
    "Status" {
        Get-AcsStatus -ResourceGroup $ResourceGroupName -ResourceName $AcsResourceName
        Show-ConfigurationSummary -ResourceGroup $ResourceGroupName -ResourceName $AcsResourceName
    }
    
    "Identity" {
        New-AcsIdentity -ResourceGroup $ResourceGroupName -ResourceName $AcsResourceName
    }
    
    "PhoneNumbers" {
        # Load config if exists
        $countryCode = "US"
        $phoneType = "tollFree"
        
        if (Test-Path $ConfigFile) {
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            if ($config.phoneNumbers) {
                $countryCode = $config.phoneNumbers.countryCode ?? "US"
                $phoneType = $config.phoneNumbers.type ?? "tollFree"
            }
        }
        
        Get-AvailablePhoneNumbers `
            -ResourceGroup $ResourceGroupName `
            -ResourceName $AcsResourceName `
            -CountryCode $countryCode `
            -PhoneNumberType $phoneType
    }
    
    "EventGrid" {
        # Auto-detect function app name
        $functionAppName = az functionapp list `
            --resource-group $ResourceGroupName `
            --query "[?contains(name, 'func-')].name | [0]" `
            --output tsv 2>$null
        
        if ($functionAppName) {
            Set-EventGridSubscriptions `
                -ResourceGroup $ResourceGroupName `
                -ResourceName $AcsResourceName `
                -FunctionAppName $functionAppName
        } else {
            Write-Status "No Function App found in '$ResourceGroupName'" -Type Error
        }
    }
    
    "All" {
        Get-AcsStatus -ResourceGroup $ResourceGroupName -ResourceName $AcsResourceName
        New-AcsIdentity -ResourceGroup $ResourceGroupName -ResourceName $AcsResourceName
        
        # Check for function app before Event Grid setup
        $functionAppName = az functionapp list `
            --resource-group $ResourceGroupName `
            --query "[?contains(name, 'func-')].name | [0]" `
            --output tsv 2>$null
        
        if ($functionAppName) {
            Set-EventGridSubscriptions `
                -ResourceGroup $ResourceGroupName `
                -ResourceName $AcsResourceName `
                -FunctionAppName $functionAppName
        }
        
        Show-ConfigurationSummary -ResourceGroup $ResourceGroupName -ResourceName $AcsResourceName
    }
}

Write-Host ""
