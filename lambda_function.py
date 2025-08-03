import json
import logging
import base64

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()


def decode_jwt_payload(token):
    """Decode JWT token payload without verification (for development/testing)"""
    try:
        # Split the JWT token into its three parts
        parts = token.split(".")
        if len(parts) != 3:
            logger.error("Invalid JWT token format")
            return None

        # Decode the payload (second part)
        payload_part = parts[1]

        # Add padding if needed for base64 decoding
        padding = 4 - len(payload_part) % 4
        if padding != 4:
            payload_part += "=" * padding

        # Decode from base64
        decoded_bytes = base64.urlsafe_b64decode(payload_part)
        payload = json.loads(decoded_bytes.decode("utf-8"))

        return payload

    except Exception as e:
        logger.error(f"Error decoding JWT payload: {e}")
        return None


def get_user_info_from_token(event):
    """Extract user information and groups from Cognito ID token"""
    try:
        # Get the ID token from the custom header
        headers = event.get("headers", {})

        # Look for custom Cognito header (case-insensitive)
        id_token = None
        for header_name, header_value in headers.items():
            if header_name.lower() == "x-cognito-id-token":
                id_token = header_value
                break

        if not id_token:
            logger.warning("No X-Cognito-Id-Token header found")
            return None, []

        # Decode the JWT token
        token_payload = decode_jwt_payload(id_token)
        if not token_payload:
            return None, []

        logger.info(f"Token payload: {token_payload}")

        # Extract user information
        user_info = {
            "username": token_payload.get("cognito:username"),
            "email": token_payload.get("email"),
            "email_verified": token_payload.get("email_verified"),
            "sub": token_payload.get("sub"),  # User's unique ID
            "aud": token_payload.get("aud"),  # Client ID
            "iss": token_payload.get("iss"),  # User Pool URL
            "token_use": token_payload.get("token_use"),  # Should be 'id'
        }

        # Extract groups - check various possible group claim names
        groups = []
        possible_group_claims = [
            "cognito:groups",
            "groups",
            "custom:groups",
            "memberOf",
            "roles",
        ]

        for claim_name in possible_group_claims:
            if claim_name in token_payload:
                claim_value = token_payload[claim_name]
                if isinstance(claim_value, list):
                    groups.extend(claim_value)
                elif isinstance(claim_value, str):
                    # Handle comma-separated string
                    groups.extend([g.strip() for g in claim_value.split(",")])
                break

        logger.info(f"User info: {user_info}")
        logger.info(f"User groups: {groups}")

        return user_info, groups

    except Exception as e:
        logger.error(f"Error extracting user info from token: {str(e)}")
        return None, []


def get_user_from_cognito_context(event):
    """Fallback method: Extract user info from Cognito context in request"""
    try:
        request_context = event.get("requestContext", {})
        identity = request_context.get("identity", {})

        # Get basic identity information
        user_info = {
            "cognito_identity_id": identity.get("cognitoIdentityId"),
            "cognito_auth_provider": identity.get("cognitoAuthenticationProvider"),
            "source_ip": identity.get("sourceIp"),
            "user_agent": identity.get("userAgent"),
        }

        logger.info(f"Cognito context user info: {user_info}")
        return user_info, []

    except Exception as e:
        logger.error(f"Error extracting user from Cognito context: {str(e)}")
        return None, []


def handler(event, context):
    logger.info("Event: %s", json.dumps(event, indent=2))
    logger.info("Context: %s", context)

    # Try to get user info from ID token first
    user_info, user_groups = get_user_info_from_token(event)

    # Fallback to Cognito context if no token found
    if not user_info:
        user_info, user_groups = get_user_from_cognito_context(event)

    # Check if user is admin
    is_admin = "Admin" in user_groups
    is_viewer = "Viewer" in user_groups

    # Extract some additional context for debugging
    request_context = event.get("requestContext", {})
    api_info = {
        "api_id": request_context.get("apiId"),
        "stage": request_context.get("stage"),
        "request_id": request_context.get("requestId"),
        "http_method": request_context.get("httpMethod"),
        "resource_path": request_context.get("resourcePath"),
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(
            {
                "message": "Hello from Lambda!",
                "user_info": user_info,
                "user_groups": user_groups,
                "is_admin": is_admin,
                "is_viewer": is_viewer,
                "api_info": api_info,
                "timestamp": context.aws_request_id,
            },
            indent=2,
        ),
    }
