// ============================================================================
// ACS Secrets Module
// ============================================================================
// Stores ACS secrets in Key Vault
// ============================================================================

@description('Key Vault name')
param keyVaultName string

@description('ACS connection string')
@secure()
param acsConnectionString string

@description('ACS endpoint')
param acsEndpoint string

// ============================================================================
// Resources
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource acsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'acs-connection-string'
  properties: {
    value: acsConnectionString
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

resource acsEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'acs-endpoint'
  properties: {
    value: acsEndpoint
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Secret URIs')
output secretUris object = {
  acsConnectionString: acsConnectionStringSecret.properties.secretUri
  acsEndpoint: acsEndpointSecret.properties.secretUri
}
