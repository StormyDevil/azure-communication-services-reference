"""
Azure Communication Services - Python SDK Sample Application

This module provides a comprehensive example of using the Azure Communication Services SDK
for various communication capabilities including:
- Identity management and token generation
- SMS messaging
- Chat functionality
- Voice/Video calling
- Email sending

Requirements:
    pip install -r requirements.txt

Configuration:
    Set the following environment variables:
    - ACS_CONNECTION_STRING: ACS connection string from Key Vault
    - ACS_ENDPOINT: ACS endpoint URL
    - AZURE_TENANT_ID: Entra ID tenant ID (for managed identity)
"""

import os
import logging
from datetime import timedelta
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from azure.identity import DefaultAzureCredential
from azure.communication.identity import CommunicationIdentityClient, CommunicationUserIdentifier
from azure.communication.sms import SmsClient
from azure.communication.chat import ChatClient, CommunicationTokenCredential
from azure.communication.email import EmailClient
from azure.core.exceptions import HttpResponseError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class ACSConfig:
    """Configuration for Azure Communication Services."""
    endpoint: str
    connection_string: Optional[str] = None
    use_managed_identity: bool = True


class ACSIdentityService:
    """
    Service for managing ACS user identities and access tokens.
    
    This service handles:
    - Creating and deleting communication users
    - Issuing and revoking access tokens
    - Token refresh for ongoing sessions
    """
    
    def __init__(self, config: ACSConfig):
        """
        Initialize the identity service.
        
        Args:
            config: ACS configuration object
        """
        self.config = config
        
        if config.use_managed_identity:
            # Preferred: Use managed identity for secure authentication
            credential = DefaultAzureCredential()
            self.client = CommunicationIdentityClient(config.endpoint, credential)
            logger.info("Identity client initialized with managed identity")
        else:
            # Fallback: Use connection string
            self.client = CommunicationIdentityClient.from_connection_string(
                config.connection_string
            )
            logger.info("Identity client initialized with connection string")
    
    def create_user(self) -> CommunicationUserIdentifier:
        """
        Create a new communication user.
        
        Returns:
            CommunicationUserIdentifier: The created user identifier
        """
        try:
            user = self.client.create_user()
            logger.info(f"Created user: {user.properties['id']}")
            return user
        except HttpResponseError as e:
            logger.error(f"Failed to create user: {e}")
            raise
    
    def create_user_with_token(
        self,
        scopes: List[str] = None,
        token_expires_in: timedelta = None
    ) -> tuple:
        """
        Create a user and issue an access token in one operation.
        
        Args:
            scopes: Token scopes (voip, chat)
            token_expires_in: Token expiration time (1-24 hours)
        
        Returns:
            Tuple of (user, token_response)
        """
        if scopes is None:
            scopes = ["voip", "chat"]
        
        if token_expires_in is None:
            token_expires_in = timedelta(hours=24)
        
        try:
            user, token_response = self.client.create_user_and_token(
                scopes=scopes,
                token_expires_in=token_expires_in
            )
            logger.info(f"Created user with token, expires: {token_response.expires_on}")
            return user, token_response
        except HttpResponseError as e:
            logger.error(f"Failed to create user with token: {e}")
            raise
    
    def get_token(
        self,
        user: CommunicationUserIdentifier,
        scopes: List[str] = None
    ) -> dict:
        """
        Get an access token for an existing user.
        
        Args:
            user: The communication user
            scopes: Token scopes
        
        Returns:
            Token response with token and expiry
        """
        if scopes is None:
            scopes = ["voip", "chat"]
        
        try:
            token_response = self.client.get_token(user, scopes=scopes)
            logger.info(f"Token issued for user, expires: {token_response.expires_on}")
            return {
                "token": token_response.token,
                "expires_on": token_response.expires_on.isoformat()
            }
        except HttpResponseError as e:
            logger.error(f"Failed to get token: {e}")
            raise
    
    def revoke_tokens(self, user: CommunicationUserIdentifier) -> None:
        """
        Revoke all tokens for a user.
        
        Args:
            user: The communication user
        """
        try:
            self.client.revoke_tokens(user)
            logger.info(f"Tokens revoked for user: {user.properties['id']}")
        except HttpResponseError as e:
            logger.error(f"Failed to revoke tokens: {e}")
            raise
    
    def delete_user(self, user: CommunicationUserIdentifier) -> None:
        """
        Delete a communication user.
        
        Args:
            user: The communication user to delete
        """
        try:
            self.client.delete_user(user)
            logger.info(f"Deleted user: {user.properties['id']}")
        except HttpResponseError as e:
            logger.error(f"Failed to delete user: {e}")
            raise


class ACSSmsService:
    """
    Service for sending SMS messages via Azure Communication Services.
    
    Features:
    - Single and bulk SMS sending
    - Delivery reports
    - Message tagging for tracking
    """
    
    def __init__(self, config: ACSConfig):
        """
        Initialize the SMS service.
        
        Args:
            config: ACS configuration object
        """
        self.config = config
        
        if config.use_managed_identity:
            credential = DefaultAzureCredential()
            self.client = SmsClient(config.endpoint, credential)
            logger.info("SMS client initialized with managed identity")
        else:
            self.client = SmsClient.from_connection_string(config.connection_string)
            logger.info("SMS client initialized with connection string")
    
    def send_sms(
        self,
        from_number: str,
        to_number: str,
        message: str,
        enable_delivery_report: bool = True,
        tag: str = None
    ) -> Dict[str, Any]:
        """
        Send an SMS message.
        
        Args:
            from_number: Sender phone number (must be ACS provisioned)
            to_number: Recipient phone number (E.164 format)
            message: Message content
            enable_delivery_report: Request delivery confirmation
            tag: Optional tag for tracking
        
        Returns:
            Send result with message ID and status
        """
        try:
            response = self.client.send(
                from_=from_number,
                to=to_number,
                message=message,
                enable_delivery_report=enable_delivery_report,
                tag=tag
            )
            
            result = response[0]
            logger.info(f"SMS sent: {result.message_id}, to: {to_number}")
            
            return {
                "message_id": result.message_id,
                "to": result.to,
                "successful": result.successful,
                "http_status": result.http_status_code
            }
        except HttpResponseError as e:
            logger.error(f"Failed to send SMS: {e}")
            raise
    
    def send_bulk_sms(
        self,
        from_number: str,
        to_numbers: List[str],
        message: str,
        enable_delivery_report: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Send SMS to multiple recipients.
        
        Args:
            from_number: Sender phone number
            to_numbers: List of recipient phone numbers
            message: Message content
            enable_delivery_report: Request delivery confirmation
        
        Returns:
            List of send results
        """
        try:
            responses = self.client.send(
                from_=from_number,
                to=to_numbers,
                message=message,
                enable_delivery_report=enable_delivery_report
            )
            
            results = []
            for result in responses:
                results.append({
                    "message_id": result.message_id,
                    "to": result.to,
                    "successful": result.successful
                })
                logger.info(f"Bulk SMS: {result.message_id} -> {result.to}")
            
            return results
        except HttpResponseError as e:
            logger.error(f"Failed to send bulk SMS: {e}")
            raise


class ACSChatService:
    """
    Service for managing chat functionality via Azure Communication Services.
    
    Features:
    - Thread creation and management
    - Message sending and receiving
    - Participant management
    - Read receipts
    """
    
    def __init__(self, endpoint: str, token: str):
        """
        Initialize the chat service.
        
        Args:
            endpoint: ACS endpoint URL
            token: User access token
        """
        self.endpoint = endpoint
        self.client = ChatClient(
            endpoint,
            CommunicationTokenCredential(token)
        )
        logger.info("Chat client initialized")
    
    def create_thread(
        self,
        topic: str,
        participants: List[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        Create a new chat thread.
        
        Args:
            topic: Thread topic/name
            participants: List of participant dicts with 'id' and 'display_name'
        
        Returns:
            Thread info with thread_id
        """
        from azure.communication.chat import ChatParticipant
        
        chat_participants = []
        if participants:
            for p in participants:
                chat_participants.append(ChatParticipant(
                    identifier=CommunicationUserIdentifier(p['id']),
                    display_name=p.get('display_name', 'User')
                ))
        
        try:
            result = self.client.create_chat_thread(
                topic=topic,
                thread_participants=chat_participants
            )
            
            thread_id = result.chat_thread.id
            logger.info(f"Chat thread created: {thread_id}")
            
            return {
                "thread_id": thread_id,
                "topic": topic,
                "created_on": result.chat_thread.created_on.isoformat()
            }
        except HttpResponseError as e:
            logger.error(f"Failed to create thread: {e}")
            raise
    
    def send_message(
        self,
        thread_id: str,
        content: str,
        sender_display_name: str = "User",
        message_type: str = "text"
    ) -> Dict[str, Any]:
        """
        Send a message to a chat thread.
        
        Args:
            thread_id: Target thread ID
            content: Message content
            sender_display_name: Display name for sender
            message_type: 'text' or 'html'
        
        Returns:
            Message info with message_id
        """
        try:
            thread_client = self.client.get_chat_thread_client(thread_id)
            
            result = thread_client.send_message(
                content=content,
                sender_display_name=sender_display_name,
                chat_message_type=message_type
            )
            
            logger.info(f"Message sent: {result.id} to thread: {thread_id}")
            
            return {
                "message_id": result.id,
                "thread_id": thread_id
            }
        except HttpResponseError as e:
            logger.error(f"Failed to send message: {e}")
            raise
    
    def list_messages(
        self,
        thread_id: str,
        max_results: int = 50
    ) -> List[Dict[str, Any]]:
        """
        List messages in a chat thread.
        
        Args:
            thread_id: Thread ID
            max_results: Maximum messages to return
        
        Returns:
            List of messages
        """
        try:
            thread_client = self.client.get_chat_thread_client(thread_id)
            messages = thread_client.list_messages(results_per_page=max_results)
            
            result = []
            for message in messages:
                result.append({
                    "id": message.id,
                    "type": message.type,
                    "content": message.content.message if message.content else None,
                    "sender_id": message.sender_communication_identifier.properties.get('id') if message.sender_communication_identifier else None,
                    "created_on": message.created_on.isoformat() if message.created_on else None
                })
            
            return result
        except HttpResponseError as e:
            logger.error(f"Failed to list messages: {e}")
            raise
    
    def add_participant(
        self,
        thread_id: str,
        user_id: str,
        display_name: str = "User"
    ) -> None:
        """
        Add a participant to a chat thread.
        
        Args:
            thread_id: Thread ID
            user_id: Communication user ID
            display_name: Display name for the user
        """
        from azure.communication.chat import ChatParticipant
        
        try:
            thread_client = self.client.get_chat_thread_client(thread_id)
            
            participant = ChatParticipant(
                identifier=CommunicationUserIdentifier(user_id),
                display_name=display_name
            )
            
            thread_client.add_participants([participant])
            logger.info(f"Added participant {user_id} to thread {thread_id}")
        except HttpResponseError as e:
            logger.error(f"Failed to add participant: {e}")
            raise
    
    def delete_thread(self, thread_id: str) -> None:
        """
        Delete a chat thread.
        
        Args:
            thread_id: Thread ID to delete
        """
        try:
            self.client.delete_chat_thread(thread_id)
            logger.info(f"Deleted thread: {thread_id}")
        except HttpResponseError as e:
            logger.error(f"Failed to delete thread: {e}")
            raise


class ACSEmailService:
    """
    Service for sending emails via Azure Communication Services.
    
    Features:
    - Transactional email sending
    - HTML and plain text support
    - Attachments
    - Multiple recipients (To, CC, BCC)
    """
    
    def __init__(self, config: ACSConfig):
        """
        Initialize the email service.
        
        Args:
            config: ACS configuration object
        """
        self.config = config
        
        if config.use_managed_identity:
            credential = DefaultAzureCredential()
            self.client = EmailClient(config.endpoint, credential)
            logger.info("Email client initialized with managed identity")
        else:
            self.client = EmailClient.from_connection_string(config.connection_string)
            logger.info("Email client initialized with connection string")
    
    def send_email(
        self,
        sender: str,
        recipients: List[str],
        subject: str,
        body_html: str = None,
        body_plain: str = None,
        cc: List[str] = None,
        bcc: List[str] = None,
        reply_to: str = None
    ) -> Dict[str, Any]:
        """
        Send an email.
        
        Args:
            sender: Sender email address (must be verified in ACS)
            recipients: List of recipient email addresses
            subject: Email subject
            body_html: HTML body content
            body_plain: Plain text body content
            cc: CC recipients
            bcc: BCC recipients
            reply_to: Reply-to address
        
        Returns:
            Send result with operation ID
        """
        try:
            # Build recipient lists
            to_recipients = [{"address": addr} for addr in recipients]
            cc_recipients = [{"address": addr} for addr in (cc or [])]
            bcc_recipients = [{"address": addr} for addr in (bcc or [])]
            
            # Build message
            message = {
                "senderAddress": sender,
                "recipients": {
                    "to": to_recipients,
                    "cc": cc_recipients,
                    "bcc": bcc_recipients
                },
                "content": {
                    "subject": subject
                }
            }
            
            if body_html:
                message["content"]["html"] = body_html
            if body_plain:
                message["content"]["plainText"] = body_plain
            
            if reply_to:
                message["replyTo"] = [{"address": reply_to}]
            
            # Send email
            poller = self.client.begin_send(message)
            result = poller.result()
            
            logger.info(f"Email sent: {result['id']}")
            
            return {
                "operation_id": result["id"],
                "status": result["status"]
            }
        except HttpResponseError as e:
            logger.error(f"Failed to send email: {e}")
            raise


# ============================================================================
# Example Usage
# ============================================================================

def main():
    """Demonstrate ACS SDK capabilities."""
    
    # Load configuration from environment
    config = ACSConfig(
        endpoint=os.environ.get("ACS_ENDPOINT", ""),
        connection_string=os.environ.get("ACS_CONNECTION_STRING"),
        use_managed_identity=os.environ.get("USE_MANAGED_IDENTITY", "true").lower() == "true"
    )
    
    if not config.endpoint:
        print("Error: ACS_ENDPOINT environment variable not set")
        print("\nSet the following environment variables:")
        print("  export ACS_ENDPOINT='https://your-acs.communication.azure.com'")
        print("  export ACS_CONNECTION_STRING='endpoint=...'  # Optional if using managed identity")
        return
    
    print("=" * 70)
    print("Azure Communication Services - SDK Demo")
    print("=" * 70)
    
    # 1. Identity Management
    print("\n1. Identity Management")
    print("-" * 40)
    
    identity_service = ACSIdentityService(config)
    
    # Create user with token
    user, token_response = identity_service.create_user_with_token(
        scopes=["voip", "chat"],
        token_expires_in=timedelta(hours=24)
    )
    print(f"   Created user: {user.properties['id'][:20]}...")
    print(f"   Token expires: {token_response.expires_on}")
    
    # 2. Chat Demo (requires valid token)
    print("\n2. Chat Functionality")
    print("-" * 40)
    
    chat_service = ACSChatService(config.endpoint, token_response.token)
    
    # Create thread
    thread = chat_service.create_thread(topic="Demo Chat Thread")
    print(f"   Created thread: {thread['thread_id'][:20]}...")
    
    # Send message
    message = chat_service.send_message(
        thread_id=thread['thread_id'],
        content="Hello from ACS SDK demo!",
        sender_display_name="Demo User"
    )
    print(f"   Sent message: {message['message_id']}")
    
    # Cleanup
    chat_service.delete_thread(thread['thread_id'])
    print("   Thread deleted")
    
    # 3. Cleanup identity
    identity_service.delete_user(user)
    print("\n3. Cleanup")
    print("-" * 40)
    print("   User deleted")
    
    print("\n" + "=" * 70)
    print("Demo completed successfully!")
    print("=" * 70)


if __name__ == "__main__":
    main()
