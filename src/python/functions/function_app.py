"""
Azure Functions - Event Processing

This module contains Azure Functions for processing ACS events via Event Grid.
Functions handle:
- Incoming SMS messages
- Chat events (messages, participants)
- Call recording status updates
"""

import logging
import json
import azure.functions as func
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
import os
from datetime import datetime

# Configure logging
logger = logging.getLogger(__name__)

# Cosmos DB configuration
COSMOS_ENDPOINT = os.environ.get("COSMOS_DB_ENDPOINT")
COSMOS_DATABASE = "acs-database"


def get_cosmos_client():
    """Get Cosmos DB client with managed identity."""
    credential = DefaultAzureCredential()
    return CosmosClient(COSMOS_ENDPOINT, credential)


app = func.FunctionApp()


@app.function_name("process_sms_received")
@app.event_grid_trigger(arg_name="event")
def process_sms_received(event: func.EventGridEvent):
    """
    Process incoming SMS messages.
    
    Event Grid delivers SMS events with structure:
    {
        "id": "...",
        "topic": "...",
        "subject": "...",
        "eventType": "Microsoft.Communication.SMSReceived",
        "data": {
            "messageId": "...",
            "from": "+1234567890",
            "to": "+0987654321",
            "message": "Hello!",
            "receivedTimestamp": "2024-01-01T00:00:00Z"
        }
    }
    """
    logger.info(f"SMS Received Event: {event.id}")
    
    try:
        data = event.get_json()
        
        sms_data = {
            "id": event.id,
            "type": "sms_received",
            "messageId": data.get("messageId"),
            "from": data.get("from"),
            "to": data.get("to"),
            "message": data.get("message"),
            "receivedAt": data.get("receivedTimestamp"),
            "processedAt": datetime.utcnow().isoformat()
        }
        
        logger.info(f"SMS from {sms_data['from']} to {sms_data['to']}")
        
        # Store in Cosmos DB for audit/history
        if COSMOS_ENDPOINT:
            client = get_cosmos_client()
            database = client.get_database_client(COSMOS_DATABASE)
            container = database.get_container_client("call-logs")
            
            container.upsert_item({
                "id": event.id,
                "callId": data.get("messageId"),  # Partition key
                "type": "sms",
                "direction": "inbound",
                "data": sms_data
            })
            
            logger.info(f"SMS logged to Cosmos DB: {event.id}")
        
        # TODO: Add business logic here
        # - Auto-reply
        # - Forward to support system
        # - Trigger workflow
        
    except Exception as e:
        logger.exception(f"Error processing SMS event: {e}")
        raise


@app.function_name("process_chat_event")
@app.event_grid_trigger(arg_name="event")
def process_chat_event(event: func.EventGridEvent):
    """
    Process chat events.
    
    Handles event types:
    - Microsoft.Communication.ChatMessageReceived
    - Microsoft.Communication.ChatThreadCreated
    - Microsoft.Communication.ChatParticipantAdded
    """
    event_type = event.event_type
    logger.info(f"Chat Event: {event_type}, ID: {event.id}")
    
    try:
        data = event.get_json()
        
        if event_type == "Microsoft.Communication.ChatMessageReceived":
            process_chat_message(event.id, data)
        elif event_type == "Microsoft.Communication.ChatThreadCreated":
            process_thread_created(event.id, data)
        elif event_type == "Microsoft.Communication.ChatParticipantAdded":
            process_participant_added(event.id, data)
        else:
            logger.warning(f"Unknown chat event type: {event_type}")
            
    except Exception as e:
        logger.exception(f"Error processing chat event: {e}")
        raise


def process_chat_message(event_id: str, data: dict):
    """Process a chat message received event."""
    thread_id = data.get("threadId")
    sender_id = data.get("senderId")
    message = data.get("messageBody")
    
    logger.info(f"Chat message in thread {thread_id[:20]}... from {sender_id[:20]}...")
    
    if COSMOS_ENDPOINT:
        client = get_cosmos_client()
        database = client.get_database_client(COSMOS_DATABASE)
        container = database.get_container_client("chat-history")
        
        container.upsert_item({
            "id": event_id,
            "threadId": thread_id,  # Partition key
            "senderId": sender_id,
            "message": message,
            "timestamp": data.get("transactionId"),
            "processedAt": datetime.utcnow().isoformat()
        })
        
        logger.info(f"Chat message logged: {event_id}")


def process_thread_created(event_id: str, data: dict):
    """Process a chat thread created event."""
    thread_id = data.get("threadId")
    created_by = data.get("createdBy")
    
    logger.info(f"Chat thread created: {thread_id[:20]}... by {created_by[:20]}...")


def process_participant_added(event_id: str, data: dict):
    """Process a participant added event."""
    thread_id = data.get("threadId")
    participants = data.get("participantsAdded", [])
    
    for p in participants:
        logger.info(f"Participant added to {thread_id[:20]}...: {p.get('id', '')[:20]}...")


@app.function_name("process_recording_event")
@app.event_grid_trigger(arg_name="event")
def process_recording_event(event: func.EventGridEvent):
    """
    Process call recording status events.
    
    Handles event type: Microsoft.Communication.RecordingFileStatusUpdated
    """
    logger.info(f"Recording Event: {event.id}")
    
    try:
        data = event.get_json()
        
        recording_status = data.get("recordingStorageInfo", {})
        recording_chunks = recording_status.get("recordingChunks", [])
        
        for chunk in recording_chunks:
            content_location = chunk.get("contentLocation")
            delete_location = chunk.get("deleteLocation")
            
            logger.info(f"Recording available at: {content_location}")
            
            # TODO: Download and process recording
            # - Transcription
            # - Sentiment analysis
            # - Compliance archiving
        
        if COSMOS_ENDPOINT:
            client = get_cosmos_client()
            database = client.get_database_client(COSMOS_DATABASE)
            container = database.get_container_client("call-logs")
            
            container.upsert_item({
                "id": event.id,
                "callId": data.get("serverCallId"),  # Partition key
                "type": "recording",
                "status": "available",
                "chunks": recording_chunks,
                "processedAt": datetime.utcnow().isoformat()
            })
            
            logger.info(f"Recording event logged: {event.id}")
            
    except Exception as e:
        logger.exception(f"Error processing recording event: {e}")
        raise


@app.function_name("health_check")
@app.timer_trigger(schedule="0 */5 * * * *", arg_name="timer")
def health_check(timer: func.TimerRequest):
    """
    Health check function that runs every 5 minutes.
    Validates connectivity to dependencies.
    """
    logger.info("Running health check...")
    
    health_status = {
        "timestamp": datetime.utcnow().isoformat(),
        "cosmos_db": "unknown",
        "key_vault": "unknown"
    }
    
    # Check Cosmos DB
    if COSMOS_ENDPOINT:
        try:
            client = get_cosmos_client()
            database = client.get_database_client(COSMOS_DATABASE)
            # Light read operation
            list(database.list_containers(max_item_count=1))
            health_status["cosmos_db"] = "healthy"
        except Exception as e:
            health_status["cosmos_db"] = f"unhealthy: {str(e)}"
            logger.error(f"Cosmos DB health check failed: {e}")
    else:
        health_status["cosmos_db"] = "not configured"
    
    logger.info(f"Health check complete: {json.dumps(health_status)}")
