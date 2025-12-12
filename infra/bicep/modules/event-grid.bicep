// ============================================================================
// Event Grid Module
// ============================================================================
// Deploys Event Grid subscription for ACS events
// ============================================================================

@description('Name for the Event Grid topic')
param eventGridTopicName string

@description('ACS resource ID')
param acsResourceId string

@description('Function App ID for event subscription')
param functionAppId string

@description('Create event subscriptions (only set true after Function App code is deployed)')
param createEventSubscriptions bool = false

@description('Tags to apply')
param tags object

// ============================================================================
// Resources
// ============================================================================

// System topic for ACS events
resource systemTopic 'Microsoft.EventGrid/systemTopics@2023-12-15-preview' = {
  name: eventGridTopicName
  location: 'global'
  tags: tags
  properties: {
    source: acsResourceId
    topicType: 'Microsoft.Communication.CommunicationServices'
  }
}

// Event subscription for incoming SMS
resource smsEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = if (createEventSubscriptions) {
  parent: systemTopic
  name: 'sms-received-subscription'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/process_sms_received'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.SMSReceived'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

// Event subscription for chat events
resource chatEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = if (createEventSubscriptions) {
  parent: systemTopic
  name: 'chat-events-subscription'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/process_chat_event'
        maxEventsPerBatch: 10
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.ChatMessageReceived'
        'Microsoft.Communication.ChatThreadCreated'
        'Microsoft.Communication.ChatParticipantAdded'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

// Event subscription for call recording
resource recordingEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = if (createEventSubscriptions) {
  parent: systemTopic
  name: 'recording-events-subscription'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/process_recording_event'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.RecordingFileStatusUpdated'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Event Grid system topic ID')
output systemTopicId string = systemTopic.id

@description('Event Grid system topic name')
output systemTopicName string = systemTopic.name
