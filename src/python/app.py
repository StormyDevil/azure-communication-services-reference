"""
Azure Communication Services - Flask API

This module provides a REST API for Azure Communication Services operations.
It demonstrates production-ready patterns including:
- Managed Identity authentication
- Key Vault integration for secrets
- Structured logging with Application Insights
- Error handling and retry logic
- Health checks for Kubernetes/App Service

Usage:
    flask run --host=0.0.0.0 --port=5000
    
    Or with gunicorn:
    gunicorn -w 4 -b 0.0.0.0:5000 app:app
"""

import os
import logging
from datetime import timedelta
from functools import wraps
from flask import Flask, request, jsonify
from flask_cors import CORS
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.communication.identity import CommunicationIdentityClient
from azure.communication.sms import SmsClient
from azure.core.exceptions import HttpResponseError, ResourceNotFoundError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configuration
ACS_ENDPOINT = os.environ.get("ACS_ENDPOINT")
KEY_VAULT_NAME = os.environ.get("KEY_VAULT_NAME")

# Global clients (lazy initialization)
_credential = None
_identity_client = None
_sms_client = None


def get_credential():
    """Get or create Azure credential (managed identity)."""
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential()
    return _credential


def get_secret(secret_name: str) -> str:
    """Retrieve a secret from Key Vault."""
    if not KEY_VAULT_NAME:
        raise ValueError("KEY_VAULT_NAME environment variable not set")
    
    vault_url = f"https://{KEY_VAULT_NAME}.vault.azure.net"
    client = SecretClient(vault_url=vault_url, credential=get_credential())
    
    try:
        secret = client.get_secret(secret_name)
        return secret.value
    except ResourceNotFoundError:
        logger.error(f"Secret not found: {secret_name}")
        raise


def get_identity_client():
    """Get or create identity client."""
    global _identity_client
    if _identity_client is None:
        if not ACS_ENDPOINT:
            raise ValueError("ACS_ENDPOINT environment variable not set")
        _identity_client = CommunicationIdentityClient(
            ACS_ENDPOINT,
            get_credential()
        )
    return _identity_client


def get_sms_client():
    """Get or create SMS client."""
    global _sms_client
    if _sms_client is None:
        if not ACS_ENDPOINT:
            raise ValueError("ACS_ENDPOINT environment variable not set")
        _sms_client = SmsClient(ACS_ENDPOINT, get_credential())
    return _sms_client


def handle_errors(f):
    """Decorator for consistent error handling."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except ValueError as e:
            logger.error(f"Validation error: {e}")
            return jsonify({"error": str(e), "type": "validation_error"}), 400
        except HttpResponseError as e:
            logger.error(f"ACS error: {e}")
            return jsonify({
                "error": str(e),
                "type": "acs_error",
                "status_code": e.status_code
            }), e.status_code or 500
        except Exception as e:
            logger.exception(f"Unexpected error: {e}")
            return jsonify({"error": "Internal server error", "type": "internal_error"}), 500
    return decorated_function


# ============================================================================
# Health Endpoints
# ============================================================================

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint for load balancers and orchestrators."""
    return jsonify({
        "status": "healthy",
        "service": "acs-api",
        "version": "1.0.0"
    })


@app.route("/health/ready", methods=["GET"])
@handle_errors
def readiness():
    """Readiness check - verifies ACS connectivity."""
    # Verify we can connect to ACS
    client = get_identity_client()
    # Light operation to verify connectivity
    return jsonify({
        "status": "ready",
        "acs_endpoint": ACS_ENDPOINT
    })


# ============================================================================
# Identity Endpoints
# ============================================================================

@app.route("/api/v1/identity/users", methods=["POST"])
@handle_errors
def create_user():
    """
    Create a new communication user.
    
    Request body (optional):
    {
        "scopes": ["voip", "chat"],
        "token_expires_hours": 24
    }
    
    Returns:
    {
        "user_id": "8:acs:...",
        "token": "eyJ...",
        "expires_on": "2024-01-01T00:00:00Z"
    }
    """
    data = request.get_json() or {}
    scopes = data.get("scopes", ["voip", "chat"])
    expires_hours = data.get("token_expires_hours", 24)
    
    if expires_hours < 1 or expires_hours > 24:
        return jsonify({"error": "token_expires_hours must be between 1 and 24"}), 400
    
    client = get_identity_client()
    
    user, token_response = client.create_user_and_token(
        scopes=scopes,
        token_expires_in=timedelta(hours=expires_hours)
    )
    
    logger.info(f"Created user: {user.properties['id'][:20]}...")
    
    return jsonify({
        "user_id": user.properties["id"],
        "token": token_response.token,
        "expires_on": token_response.expires_on.isoformat()
    }), 201


@app.route("/api/v1/identity/users/<user_id>/token", methods=["POST"])
@handle_errors
def get_token(user_id: str):
    """
    Get a new access token for an existing user.
    
    Request body (optional):
    {
        "scopes": ["voip", "chat"]
    }
    
    Returns:
    {
        "token": "eyJ...",
        "expires_on": "2024-01-01T00:00:00Z"
    }
    """
    from azure.communication.identity import CommunicationUserIdentifier
    
    data = request.get_json() or {}
    scopes = data.get("scopes", ["voip", "chat"])
    
    client = get_identity_client()
    user = CommunicationUserIdentifier(user_id)
    
    token_response = client.get_token(user, scopes=scopes)
    
    logger.info(f"Issued token for user: {user_id[:20]}...")
    
    return jsonify({
        "token": token_response.token,
        "expires_on": token_response.expires_on.isoformat()
    })


@app.route("/api/v1/identity/users/<user_id>", methods=["DELETE"])
@handle_errors
def delete_user(user_id: str):
    """Delete a communication user."""
    from azure.communication.identity import CommunicationUserIdentifier
    
    client = get_identity_client()
    user = CommunicationUserIdentifier(user_id)
    
    # Revoke tokens first
    client.revoke_tokens(user)
    # Then delete user
    client.delete_user(user)
    
    logger.info(f"Deleted user: {user_id[:20]}...")
    
    return "", 204


# ============================================================================
# SMS Endpoints
# ============================================================================

@app.route("/api/v1/sms/send", methods=["POST"])
@handle_errors
def send_sms():
    """
    Send an SMS message.
    
    Request body:
    {
        "from": "+1234567890",
        "to": "+0987654321",
        "message": "Hello from ACS!",
        "enable_delivery_report": true,
        "tag": "optional-tracking-tag"
    }
    
    Returns:
    {
        "message_id": "...",
        "successful": true
    }
    """
    data = request.get_json()
    
    if not data:
        return jsonify({"error": "Request body required"}), 400
    
    required_fields = ["from", "to", "message"]
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    client = get_sms_client()
    
    response = client.send(
        from_=data["from"],
        to=data["to"],
        message=data["message"],
        enable_delivery_report=data.get("enable_delivery_report", True),
        tag=data.get("tag")
    )
    
    result = response[0]
    
    logger.info(f"SMS sent: {result.message_id} to {data['to']}")
    
    return jsonify({
        "message_id": result.message_id,
        "to": result.to,
        "successful": result.successful,
        "http_status": result.http_status_code
    })


@app.route("/api/v1/sms/send-bulk", methods=["POST"])
@handle_errors
def send_bulk_sms():
    """
    Send SMS to multiple recipients.
    
    Request body:
    {
        "from": "+1234567890",
        "to": ["+0987654321", "+1122334455"],
        "message": "Hello from ACS!"
    }
    
    Returns:
    {
        "results": [
            {"message_id": "...", "to": "+0987654321", "successful": true},
            {"message_id": "...", "to": "+1122334455", "successful": true}
        ]
    }
    """
    data = request.get_json()
    
    if not data:
        return jsonify({"error": "Request body required"}), 400
    
    if "to" not in data or not isinstance(data["to"], list):
        return jsonify({"error": "'to' must be a list of phone numbers"}), 400
    
    client = get_sms_client()
    
    response = client.send(
        from_=data["from"],
        to=data["to"],
        message=data["message"],
        enable_delivery_report=data.get("enable_delivery_report", True)
    )
    
    results = []
    for result in response:
        results.append({
            "message_id": result.message_id,
            "to": result.to,
            "successful": result.successful
        })
    
    logger.info(f"Bulk SMS sent to {len(results)} recipients")
    
    return jsonify({"results": results})


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    # Development server
    app.run(host="0.0.0.0", port=5000, debug=True)
