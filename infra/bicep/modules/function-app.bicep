// ============================================================================
// Azure Functions Module
// ============================================================================
// Deploys Function App for event processing
// ============================================================================

@description('Azure region for deployment')
param location string

@description('Name for the Function App')
param functionAppName string

@description('App Service Plan ID')
param appServicePlanId string

@description('Storage Account name')
param storageAccountName string

@description('Key Vault name for secrets')
param keyVaultName string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('ACS endpoint')
param acsEndpoint string

@description('Cosmos DB endpoint')
param cosmosDbEndpoint string

@description('Enable diagnostic settings')
param enableDiagnostics bool

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      minTlsVersion: '1.2'
      http20Enabled: true
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ACS_ENDPOINT'
          value: acsEndpoint
        }
        {
          name: 'COSMOS_DB_ENDPOINT'
          value: cosmosDbEndpoint
        }
        {
          name: 'KEY_VAULT_NAME'
          value: keyVaultName
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

// Grant Key Vault access to Function App managed identity
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionApp.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
  }
}

// Grant Storage Blob Data Owner to Function App for identity-based storage access
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, 'Storage Blob Data Owner')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${functionAppName}'
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Function App resource ID')
output functionAppId string = functionApp.id

@description('Function App name')
output functionAppName string = functionApp.name

@description('Function App URL')
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'

@description('Function App managed identity principal ID')
output functionAppPrincipalId string = functionApp.identity.principalId
