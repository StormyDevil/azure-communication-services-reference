// ============================================================================
// Azure Communication Services Module
// ============================================================================
// Deploys ACS resource with diagnostic settings
// ============================================================================

@description('Name for the ACS resource')
param acsName string

@description('Data location for ACS')
param dataLocation string

@description('Enable diagnostic settings')
param enableDiagnostics bool

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource communicationServices 'Microsoft.Communication/communicationServices@2023-06-01-preview' = {
  name: acsName
  location: 'global' // ACS is a global service
  tags: tags
  properties: {
    dataLocation: dataLocation
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${acsName}'
  scope: communicationServices
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
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

@description('ACS resource ID')
output acsResourceId string = communicationServices.id

@description('ACS endpoint')
output acsEndpoint string = 'https://${communicationServices.properties.hostName}'

@description('ACS connection string')
@secure()
output acsConnectionString string = communicationServices.listKeys().primaryConnectionString

@description('ACS primary key')
@secure()
output acsPrimaryKey string = communicationServices.listKeys().primaryKey
