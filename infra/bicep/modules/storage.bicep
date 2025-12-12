// ============================================================================
// Storage Account Module
// ============================================================================
// Deploys Storage Account for recordings and attachments
// ============================================================================

@description('Azure region for deployment')
param location string

@description('Name for the Storage Account')
param storageAccountName string

@description('Enable diagnostic settings')
param enableDiagnostics bool

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Require Entra ID authentication
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Container for call recordings
resource recordingsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'call-recordings'
  properties: {
    publicAccess: 'None'
  }
}

// Container for chat attachments
resource attachmentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'chat-attachments'
  properties: {
    publicAccess: 'None'
  }
}

// Diagnostic settings for blob service
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${storageAccountName}'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Storage Account resource ID')
output storageAccountId string = storageAccount.id

@description('Storage Account name')
output storageAccountName string = storageAccount.name

@description('Blob endpoint')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
