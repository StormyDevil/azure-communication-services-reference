// ============================================================================
// Azure Communication Services - Enterprise Reference Architecture
// Main Deployment Template
// ============================================================================
// This template deploys a complete ACS solution following:
// - Cloud Adoption Framework (CAF) naming conventions
// - Well-Architected Framework (WAF) best practices
// - Azure Landing Zone integration patterns
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name for resource naming (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Project name used in resource naming')
@minLength(3)
@maxLength(10)
param projectName string = 'acsref'

@description('Azure region for deployment. ACS is globally available but supporting resources need a location.')
param location string = resourceGroup().location

@description('Enable SMS capability')
param enableSms bool = true

@description('Enable Voice/PSTN capability')
param enableVoice bool = true

@description('Enable Video capability')
param enableVideo bool = true

@description('Enable Chat capability')
param enableChat bool = true

@description('Enable Email capability')
param enableEmail bool = false

@description('Enable advanced messaging (WhatsApp)')
param enableAdvancedMessaging bool = false

@description('Data location for ACS resource')
@allowed(['Africa', 'Asia Pacific', 'Australia', 'Brazil', 'Canada', 'Europe', 'France', 'Germany', 'India', 'Japan', 'Korea', 'Norway', 'Switzerland', 'UAE', 'UK', 'United States'])
param acsDataLocation string = 'Europe'

@description('Deploy sample application (App Service and Function App)')
param deployApplication bool = true

@description('App Service Plan SKU')
@allowed(['B1', 'B2', 'S1', 'S2', 'P1v3', 'P2v3'])
param appServicePlanSku string = 'S1'

@description('Enable diagnostic logging')
param enableDiagnostics bool = true

@description('Log retention in days')
@minValue(30)
@maxValue(365)
param logRetentionDays int = 90

@description('Tags to apply to all resources')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

// Generate unique suffix for globally unique names
var uniqueSuffix = uniqueString(resourceGroup().id)

// Resource naming following CAF conventions
var names = {
  acs: 'acs-${projectName}-${environment}'
  appService: 'app-${projectName}-${environment}-${take(uniqueSuffix, 4)}'
  appServicePlan: 'asp-${projectName}-${environment}'
  functionApp: 'func-${projectName}-${environment}-${take(uniqueSuffix, 4)}'
  keyVault: 'kv-${take(projectName, 6)}-${environment}-${take(uniqueSuffix, 4)}'
  cosmosDb: 'cosmos-${projectName}-${environment}-${take(uniqueSuffix, 4)}'
  storageAccount: 'st${take(replace(projectName, '-', ''), 8)}${environment}${take(uniqueSuffix, 4)}'
  logAnalytics: 'log-${projectName}-${environment}'
  appInsights: 'appi-${projectName}-${environment}'
  eventGrid: 'evgt-${projectName}-${environment}'
}

// Default tags merged with provided tags
var defaultTags = {
  Environment: environment
  Project: projectName
  ManagedBy: 'Bicep'
  Solution: 'AzureCommunicationServices'
  WAFCompliant: 'true'
}

var allTags = union(defaultTags, tags)

// ============================================================================
// Modules
// ============================================================================

// Monitoring (deploy first for diagnostic settings)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    location: location
    logAnalyticsName: names.logAnalytics
    appInsightsName: names.appInsights
    retentionDays: logRetentionDays
    tags: allTags
  }
}

// Key Vault (deploy early for secrets)
module keyVault 'modules/key-vault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    location: location
    keyVaultName: names.keyVault
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    tags: allTags
  }
}

// Storage Account (for recordings, chat attachments)
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountName: names.storageAccount
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    tags: allTags
  }
}

// Azure Communication Services
module communicationServices 'modules/communication-services.bicep' = {
  name: 'acs-deployment'
  params: {
    acsName: names.acs
    dataLocation: acsDataLocation
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    tags: allTags
  }
}

// Cosmos DB (for chat history, user profiles)
module cosmosDb 'modules/cosmos-db.bicep' = if (enableChat) {
  name: 'cosmosdb-deployment'
  params: {
    location: location
    cosmosDbAccountName: names.cosmosDb
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    tags: allTags
  }
}

// App Service (Backend API) - Optional
module appService 'modules/app-service.bicep' = if (deployApplication) {
  name: 'appservice-deployment'
  params: {
    location: location
    appServiceName: names.appService
    appServicePlanName: names.appServicePlan
    appServicePlanSku: appServicePlanSku
    keyVaultName: keyVault.outputs.keyVaultName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    acsEndpoint: communicationServices.outputs.acsEndpoint
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    tags: allTags
  }
}

// Azure Functions (Event processing) - Optional
module functionApp 'modules/function-app.bicep' = if (deployApplication) {
  name: 'functionapp-deployment'
  params: {
    location: location
    functionAppName: names.functionApp
    appServicePlanId: appService!.outputs.appServicePlanId
    storageAccountName: storage.outputs.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    acsEndpoint: communicationServices.outputs.acsEndpoint
    cosmosDbEndpoint: enableChat ? cosmosDb!.outputs.cosmosDbEndpoint : ''
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    tags: allTags
  }
}

// Event Grid (ACS event subscriptions) - Optional (requires Function App)
// Note: Event subscriptions require deployed function code, so createEventSubscriptions is false by default
module eventGrid 'modules/event-grid.bicep' = if (deployApplication) {
  name: 'eventgrid-deployment'
  params: {
    eventGridTopicName: names.eventGrid
    acsResourceId: communicationServices.outputs.acsResourceId
    functionAppId: functionApp!.outputs.functionAppId
    createEventSubscriptions: false // Set to true after deploying function code
    tags: allTags
  }
}

// Store ACS connection string in Key Vault
module acsSecrets 'modules/acs-secrets.bicep' = {
  name: 'acs-secrets-deployment'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    acsConnectionString: communicationServices.outputs.acsConnectionString
    acsEndpoint: communicationServices.outputs.acsEndpoint
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('Azure Communication Services endpoint')
output acsEndpoint string = communicationServices.outputs.acsEndpoint

@description('Azure Communication Services resource ID')
output acsResourceId string = communicationServices.outputs.acsResourceId

@description('App Service URL (if application deployed)')
output appServiceUrl string = deployApplication ? appService!.outputs.appServiceUrl : ''

@description('Function App URL (if application deployed)')
output functionAppUrl string = deployApplication ? functionApp!.outputs.functionAppUrl : ''

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Cosmos DB endpoint (if chat enabled)')
output cosmosDbEndpoint string = enableChat ? cosmosDb!.outputs.cosmosDbEndpoint : ''

@description('Storage Account name')
output storageAccountName string = storage.outputs.storageAccountName

@description('Enabled capabilities')
output enabledCapabilities object = {
  sms: enableSms
  voice: enableVoice
  video: enableVideo
  chat: enableChat
  email: enableEmail
  advancedMessaging: enableAdvancedMessaging
}

@description('Application deployed')
output applicationDeployed bool = deployApplication
