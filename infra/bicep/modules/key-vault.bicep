// ============================================================================
// Key Vault Module
// ============================================================================
// Deploys Key Vault with secure configuration
// ============================================================================

@description('Azure region for deployment')
param location string

@description('Name for the Key Vault')
param keyVaultName string

@description('Enable diagnostic settings')
param enableDiagnostics bool

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // Use RBAC instead of access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true // Protect against accidental deletion
    publicNetworkAccess: 'Enabled' // Can be disabled for private endpoints
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${keyVaultName}'
  scope: keyVault
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

@description('Key Vault resource ID')
output keyVaultId string = keyVault.id

@description('Key Vault name')
output keyVaultName string = keyVault.name

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri
