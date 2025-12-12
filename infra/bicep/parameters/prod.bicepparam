// ============================================================================
// Production Environment Parameters
// ============================================================================

using '../main.bicep'

param environment = 'prod'
param projectName = 'acsref'

// ACS Configuration - adjust based on your data residency requirements
param acsDataLocation = 'Europe'

// Capabilities
param enableSms = true
param enableVoice = true
param enableVideo = true
param enableChat = true
param enableEmail = true
param enableAdvancedMessaging = true

// Resource sizing (production-grade)
param appServicePlanSku = 'P1v3'

// Application deployment (set to false for infrastructure-only)
param deployApplication = true

// Monitoring
param enableDiagnostics = true
param logRetentionDays = 365

// Tags
param tags = {
  Environment: 'Production'
  CostCenter: 'Operations'
  Owner: 'Platform Team'
  Criticality: 'High'
  SLA: '99.9%'
}
