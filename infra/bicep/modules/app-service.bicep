// ============================================================================
// App Service Module
// ============================================================================
// Deploys App Service for backend API
// ============================================================================

@description('Azure region for deployment')
param location string

@description('Name for the App Service')
param appServiceName string

@description('Name for the App Service Plan')
param appServicePlanName string

@description('App Service Plan SKU')
param appServicePlanSku string

@description('Key Vault name for secrets')
param keyVaultName string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('ACS endpoint')
param acsEndpoint string

@description('Enable diagnostic settings')
param enableDiagnostics bool

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true // Linux
  }
}

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      minTlsVersion: '1.2'
      http20Enabled: true
      ftpsState: 'Disabled'
      alwaysOn: appServicePlanSku != 'B1' && appServicePlanSku != 'B2'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ACS_ENDPOINT'
          value: acsEndpoint
        }
        {
          name: 'KEY_VAULT_NAME'
          value: keyVaultName
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '0'
        }
      ]
    }
  }
}

// Grant Key Vault access to App Service managed identity
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appService.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${appServiceName}'
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
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

@description('App Service resource ID')
output appServiceId string = appService.id

@description('App Service name')
output appServiceName string = appService.name

@description('App Service URL')
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

@description('App Service Plan ID')
output appServicePlanId string = appServicePlan.id

@description('App Service managed identity principal ID')
output appServicePrincipalId string = appService.identity.principalId
