// ============================================================================
// Cosmos DB Module
// ============================================================================
// Deploys Cosmos DB for chat history and user data
// ============================================================================

@description('Azure region for deployment')
param location string

@description('Name for the Cosmos DB account')
param cosmosDbAccountName string

@description('Enable diagnostic settings')
param enableDiagnostics bool

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosDbAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: true
    enableMultipleWriteLocations: false
    disableLocalAuth: true // Require Entra ID authentication
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 720
        backupStorageRedundancy: 'Local'
      }
    }
    capabilities: [
      {
        name: 'EnableServerless' // Use serverless for dev/test
      }
    ]
  }
}

// Database
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosDbAccount
  name: 'acs-database'
  properties: {
    resource: {
      id: 'acs-database'
    }
  }
}

// Chat history container
resource chatHistoryContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'chat-history'
  properties: {
    resource: {
      id: 'chat-history'
      partitionKey: {
        paths: ['/threadId']
        kind: 'Hash'
      }
      indexingPolicy: {
        automatic: true
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      defaultTtl: 2592000 // 30 days
    }
  }
}

// User profiles container
resource userProfilesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'user-profiles'
  properties: {
    resource: {
      id: 'user-profiles'
      partitionKey: {
        paths: ['/userId']
        kind: 'Hash'
      }
    }
  }
}

// Call logs container
resource callLogsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'call-logs'
  properties: {
    resource: {
      id: 'call-logs'
      partitionKey: {
        paths: ['/callId']
        kind: 'Hash'
      }
      defaultTtl: 7776000 // 90 days
    }
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${cosmosDbAccountName}'
  scope: cosmosDbAccount
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
        category: 'Requests'
        enabled: true
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Cosmos DB account ID')
output cosmosDbAccountId string = cosmosDbAccount.id

@description('Cosmos DB account name')
output cosmosDbAccountName string = cosmosDbAccount.name

@description('Cosmos DB endpoint')
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint

@description('Database name')
output databaseName string = database.name
