// ============================================================================
// Monitoring Module
// ============================================================================
// Deploys Log Analytics and Application Insights
// ============================================================================

@description('Azure region for deployment')
param location string

@description('Name for Log Analytics workspace')
param logAnalyticsName string

@description('Name for Application Insights')
param appInsightsName string

@description('Log retention in days')
param retentionDays int

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Log Analytics workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.id

@description('Log Analytics workspace name')
output logAnalyticsWorkspaceName string = logAnalytics.name

@description('Application Insights resource ID')
output appInsightsId string = appInsights.id

@description('Application Insights instrumentation key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights connection string')
output appInsightsConnectionString string = appInsights.properties.ConnectionString
