// ============================================================================
// Development Environment Parameters
// ============================================================================

using '../main.bicep'

param environment = 'dev'
param projectName = 'acsref'

// ACS Configuration
param acsDataLocation = 'Europe'

// Capabilities (all enabled for dev)
param enableSms = true
param enableVoice = true
param enableVideo = true
param enableChat = true
param enableEmail = false
param enableAdvancedMessaging = false

// Resource sizing (cost-optimized for dev)
param appServicePlanSku = 'B1'

// Application deployment (set to false for infrastructure-only)
param deployApplication = true

// Monitoring
param enableDiagnostics = true
param logRetentionDays = 30

// Tags
param tags = {
  Environment: 'Development'
  CostCenter: 'Engineering'
  Owner: 'Platform Team'
}
