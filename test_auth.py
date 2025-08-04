#!/usr/bin/env python
import getpass
import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.credentials import Credentials

# Try to import pycognito for SRP authentication
try:
    from pycognito import Cognito

    PYCOGNITO_AVAILABLE = True
except ImportError:
    Cognito = None
    PYCOGNITO_AVAILABLE = False

AWS_PROFILE = os.getenv("AWS_PROFILE", "default")


@dataclass
class AWSConfig:
    """Configuration class to hold AWS and Cognito settings"""

    api_endpoint: str
    aws_region: str
    user_pool_id: str
    client_id: str
    identity_pool_id: str
    aws_profile: str = AWS_PROFILE


def get_terraform_outputs() -> AWSConfig | None:
    """Get configuration from Terraform outputs"""

    try:
        # Get the directory where the script is located (should contain terraform files)
        script_dir = Path(__file__).parent.resolve()

        print("Loading configuration from Terraform outputs...")
        result = subprocess.run(
            ["terraform", "output", "-json"],
            capture_output=True,
            text=True,
            cwd=script_dir,
            check=True,
        )

        outputs = json.loads(result.stdout)

        # Extract values from Terraform outputs and create config object
        config = AWSConfig(
            api_endpoint=outputs["api_endpoint"]["value"],
            aws_region=outputs["cognito_region"]["value"],
            user_pool_id=outputs["cognito_user_pool_id"]["value"],
            client_id=outputs["cognito_client_id"]["value"],
            identity_pool_id=outputs["cognito_identity_pool_id"]["value"],
        )

        print(f"✓ API Endpoint: {config.api_endpoint}")
        print(f"✓ AWS Region: {config.aws_region}")
        print(f"✓ User Pool ID: {config.user_pool_id}")
        print(f"✓ Client ID: {config.client_id}")
        print(f"✓ Identity Pool ID: {config.identity_pool_id}")
        print("-" * 50)

        return config

    except Exception as e:
        print(f"Error loading Terraform outputs: {e}")
        print(
            "Make sure you're running this script from the directory containing your Terraform files"
        )
        print("and that 'terraform output' command works in that directory.")
        return None


def test_plain_endpoint(config: AWSConfig):
    """Test the /test/plain endpoint without authentication"""
    print("Testing /test/plain endpoint (no auth)...")
    try:
        url = f"{config.api_endpoint}/test/plain"
        response = requests.get(url, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        print("-" * 50)
        return response
    except Exception as e:
        print(f"Error calling plain endpoint: {e}")
        print("-" * 50)
        return None


def test_auth_endpoint(config: AWSConfig):
    """Test the /test/auth endpoint with IAM authentication"""
    print("Testing /test/auth endpoint (IAM auth)...")
    try:
        # Create a session with the specified profile
        session = boto3.Session(profile_name=config.aws_profile)
        credentials = session.get_credentials()

        # Create the request
        url = f"{config.api_endpoint}/test/auth"
        request = AWSRequest(method="GET", url=url)

        # Sign the request with SigV4
        SigV4Auth(credentials, "execute-api", config.aws_region).add_auth(request)

        # Convert to a requests-compatible format
        headers = dict(request.headers)

        # Make the authenticated request
        response = requests.get(url, headers=headers, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        print("-" * 50)
        return response
    except Exception as e:
        print(f"Error calling auth endpoint: {e}")
        print("-" * 50)
        return None


def test_cognito_auth_endpoint(config: AWSConfig, username=None, password=None):
    """Test the /test/auth endpoint using Cognito authentication"""
    print("Testing /test/auth endpoint (Cognito auth)...")
    try:
        # Create a session with the specified profile for Cognito operations
        session = boto3.Session(profile_name=config.aws_profile)

        # Get username and password if not provided
        if not username:
            username = input("Enter Cognito username: ").strip()
            if not username:
                print("Username is required")
                return None
        if not password:
            password = getpass.getpass("Enter password: ")
            if not password:
                print("Password is required")
                return None

        # Step 1: Authenticate with Cognito User Pool
        cognito_client = session.client("cognito-idp", region_name=config.aws_region)

        print("Step 1: Authenticating with Cognito User Pool...")
        auth_response = cognito_client.initiate_auth(
            ClientId=config.client_id,
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={"USERNAME": username, "PASSWORD": password},
        )

        id_token = auth_response["AuthenticationResult"]["IdToken"]
        # access_token = auth_response["AuthenticationResult"]["AccessToken"]  # Unused for now
        print("✓ Successfully authenticated with User Pool")

        # Step 2: Get Identity ID from Identity Pool
        cognito_identity = session.client(
            "cognito-identity", region_name=config.aws_region
        )

        print("Step 2: Getting Identity ID from Identity Pool...")
        identity_response = cognito_identity.get_id(
            IdentityPoolId=config.identity_pool_id,
            Logins={
                f"cognito-idp.{config.aws_region}.amazonaws.com/{config.user_pool_id}": id_token
            },
        )

        identity_id = identity_response["IdentityId"]
        print(f"✓ Got Identity ID: {identity_id}")

        # Step 3: Get AWS credentials for the identity
        print("Step 3: Getting AWS credentials for the identity...")
        credentials_response = cognito_identity.get_credentials_for_identity(
            IdentityId=identity_id,
            Logins={
                f"cognito-idp.{config.aws_region}.amazonaws.com/{config.user_pool_id}": id_token
            },
        )

        aws_credentials = credentials_response["Credentials"]
        print("✓ Got AWS credentials from Identity Pool")

        # Step 4: Create AWS credentials object for signing
        creds = Credentials(
            access_key=aws_credentials["AccessKeyId"],
            secret_key=aws_credentials["SecretKey"],
            token=aws_credentials["SessionToken"],
        )

        # Step 5: Make authenticated request to API Gateway
        print("Step 4: Making authenticated request to API Gateway...")
        url = f"{config.api_endpoint}/test/auth"
        request = AWSRequest(method="GET", url=url)

        # Sign the request with SigV4 using Cognito-derived credentials
        SigV4Auth(creds, "execute-api", config.aws_region).add_auth(request)

        # Convert to a requests-compatible format
        headers = dict(request.headers)

        # Add the ID token as a custom header for API Gateway to extract user details
        headers["X-Cognito-Id-Token"] = id_token

        # Make the authenticated request
        response = requests.get(url, headers=headers, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        print("-" * 50)
        return response
    except Exception as e:
        print(f"Error with Cognito authentication: {e}")
        print("-" * 50)
        return None


def test_cognito_srp_auth(config: AWSConfig, username=None, password=None):
    """Test the /test/auth endpoint using Cognito SRP authentication"""
    print("Testing /test/auth endpoint (Cognito SRP auth)...")

    if not PYCOGNITO_AVAILABLE:
        print("⚠️  SRP authentication requires 'pycognito' library")
        print("   Install with: pip install pycognito")
        print("   Falling back to password authentication...")
        return test_cognito_auth_endpoint(config, username, password)

    try:
        # Get username and password if not provided
        if not username:
            username = input("Enter Cognito username: ").strip()
            if not username:
                print("Username is required")
                return None
        if not password:
            password = getpass.getpass("Enter password: ")
            if not password:
                print("Password is required")
                return None

        # Authenticate with SRP using pycognito library
        print("Step 1: Authenticating with SRP using pycognito library...")
        if Cognito is None:
            raise RuntimeError("pycognito not available")

        try:
            u = Cognito(config.user_pool_id, config.client_id, username=username)
            u.authenticate(password=password)

            id_token = u.id_token
            # access_token = u.access_token  # Unused for now
            print("✓ Successfully authenticated with SRP")
        except Exception as srp_error:
            print(f"⚠️  SRP authentication failed: {srp_error}")
            print("   This could be due to:")
            print("   - User Pool settings (SRP might be disabled)")
            print("   - Client app settings (USER_SRP_AUTH flow might not be enabled)")
            print("   - pycognito library compatibility issues")
            print("   - Network/connectivity issues")
            print("   Falling back to password authentication...")
            return test_cognito_auth_endpoint(config, username, password)

        # Continue with Identity Pool flow
        session = boto3.Session(profile_name=config.aws_profile)
        cognito_identity = session.client(
            "cognito-identity", region_name=config.aws_region
        )

        print("Step 2: Getting Identity ID from Identity Pool...")
        identity_response = cognito_identity.get_id(
            IdentityPoolId=config.identity_pool_id,
            Logins={
                f"cognito-idp.{config.aws_region}.amazonaws.com/{config.user_pool_id}": id_token
            },
        )

        identity_id = identity_response["IdentityId"]
        print(f"✓ Got Identity ID: {identity_id}")

        # Step 3: Get AWS credentials for the identity
        print("Step 3: Getting AWS credentials for the identity...")
        credentials_response = cognito_identity.get_credentials_for_identity(
            IdentityId=identity_id,
            Logins={
                f"cognito-idp.{config.aws_region}.amazonaws.com/{config.user_pool_id}": id_token
            },
        )

        aws_credentials = credentials_response["Credentials"]
        print("✓ Got AWS credentials from Identity Pool")

        # Step 4: Create AWS credentials object for signing
        creds = Credentials(
            access_key=aws_credentials["AccessKeyId"],
            secret_key=aws_credentials["SecretKey"],
            token=aws_credentials["SessionToken"],
        )

        # Step 5: Make authenticated request to API Gateway
        print("Step 4: Making authenticated request to API Gateway...")
        url = f"{config.api_endpoint}/test/auth"
        request = AWSRequest(method="GET", url=url)

        # Sign the request with SigV4 using Cognito-derived credentials
        SigV4Auth(creds, "execute-api", config.aws_region).add_auth(request)

        # Convert to a requests-compatible format
        headers = dict(request.headers)

        # Add the ID token as a custom header for API Gateway to extract user details
        headers["X-Cognito-Id-Token"] = id_token

        # Make the authenticated request
        response = requests.get(url, headers=headers, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        print("-" * 50)
        return response
    except Exception as e:
        print(f"Error with Cognito SRP authentication: {e}")
        print("-" * 50)
        return None


def test_unauthenticated_endpoint(config: AWSConfig):
    """Test the /test/public endpoint using unauthenticated Cognito identity"""
    print("Testing /test/public endpoint (Unauthenticated Cognito identity)...")
    try:
        # Create a session with the specified profile for Cognito operations
        session = boto3.Session(profile_name=config.aws_profile)

        # Step 1: Get Identity ID from Identity Pool (without authentication)
        cognito_identity = session.client(
            "cognito-identity", region_name=config.aws_region
        )

        print("Step 1: Getting unauthenticated Identity ID from Identity Pool...")
        identity_response = cognito_identity.get_id(
            IdentityPoolId=config.identity_pool_id,
            # No Logins parameter = unauthenticated access
        )

        identity_id = identity_response["IdentityId"]
        print(f"✓ Got unauthenticated Identity ID: {identity_id}")

        # Step 2: Get AWS credentials for the unauthenticated identity
        print("Step 2: Getting AWS credentials for the unauthenticated identity...")
        credentials_response = cognito_identity.get_credentials_for_identity(
            IdentityId=identity_id,
            # No Logins parameter = unauthenticated access
        )

        aws_credentials = credentials_response["Credentials"]
        print("✓ Got AWS credentials from Identity Pool (unauthenticated role)")

        # Step 3: Create AWS credentials object for signing
        creds = Credentials(
            access_key=aws_credentials["AccessKeyId"],
            secret_key=aws_credentials["SecretKey"],
            token=aws_credentials["SessionToken"],
        )

        # Step 4: Make authenticated request to API Gateway /test/public endpoint
        print("Step 3: Making authenticated request to /test/public endpoint...")
        url = f"{config.api_endpoint}/test/public"
        request = AWSRequest(method="GET", url=url)

        # Sign the request with SigV4 using unauthenticated Cognito-derived credentials
        SigV4Auth(creds, "execute-api", config.aws_region).add_auth(request)

        # Convert to a requests-compatible format
        headers = dict(request.headers)

        # Make the authenticated request
        response = requests.get(url, headers=headers, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        print("-" * 50)
        return response
    except Exception as e:
        print(f"Error with unauthenticated Cognito identity: {e}")
        print("-" * 50)
        return None


def test_unauthenticated_auth_endpoint(config: AWSConfig):
    """Test the /test/auth endpoint using unauthenticated Cognito identity (should fail)"""
    print(
        "Testing /test/auth endpoint (Unauthenticated Cognito identity - should fail)..."
    )
    try:
        # Create a session with the specified profile for Cognito operations
        session = boto3.Session(profile_name=config.aws_profile)

        # Step 1: Get Identity ID from Identity Pool (without authentication)
        cognito_identity = session.client(
            "cognito-identity", region_name=config.aws_region
        )

        print("Step 1: Getting unauthenticated Identity ID from Identity Pool...")
        identity_response = cognito_identity.get_id(
            IdentityPoolId=config.identity_pool_id,
            # No Logins parameter = unauthenticated access
        )

        identity_id = identity_response["IdentityId"]
        print(f"✓ Got unauthenticated Identity ID: {identity_id}")

        # Step 2: Get AWS credentials for the unauthenticated identity
        print("Step 2: Getting AWS credentials for the unauthenticated identity...")
        credentials_response = cognito_identity.get_credentials_for_identity(
            IdentityId=identity_id,
            # No Logins parameter = unauthenticated access
        )

        aws_credentials = credentials_response["Credentials"]
        print("✓ Got AWS credentials from Identity Pool (unauthenticated role)")

        # Step 3: Create AWS credentials object for signing
        creds = Credentials(
            access_key=aws_credentials["AccessKeyId"],
            secret_key=aws_credentials["SecretKey"],
            token=aws_credentials["SessionToken"],
        )

        # Step 4: Try to access /test/auth endpoint (should be denied)
        print("Step 3: Attempting to access /test/auth endpoint (expecting 403)...")
        url = f"{config.api_endpoint}/test/auth"
        request = AWSRequest(method="GET", url=url)

        # Sign the request with SigV4 using unauthenticated Cognito-derived credentials
        SigV4Auth(creds, "execute-api", config.aws_region).add_auth(request)

        # Convert to a requests-compatible format
        headers = dict(request.headers)

        # Make the authenticated request
        response = requests.get(url, headers=headers, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")

        # For this test, 403 is the expected success case
        if response.status_code == 403:
            print(
                "✓ Expected 403 Forbidden - unauthenticated role correctly denied access"
            )
        else:
            print(
                "⚠️ Unexpected response - unauthenticated role should not have access to /test/auth"
            )

        print("-" * 50)
        return response

    except Exception as e:
        print(f"Error with unauthenticated Cognito identity: {e}")
        print("-" * 50)
        return None


def main():
    # Load configuration from Terraform outputs
    config = get_terraform_outputs()
    if not config:
        print("Failed to load Terraform configuration. Exiting.")
        return

    print(f"API Endpoint: {config.api_endpoint}")
    print(f"AWS Profile: {config.aws_profile}")
    print(f"AWS Region: {config.aws_region}")
    print(f"User Pool ID: {config.user_pool_id}")
    print(f"Client ID: {config.client_id}")
    print(f"Identity Pool ID: {config.identity_pool_id}")
    print("=" * 50)

    # Test all endpoints
    plain_response = test_plain_endpoint(config)
    iam_auth_response = test_auth_endpoint(config)

    # Test unauthenticated Cognito identity
    print("\nTesting Unauthenticated Cognito Identity:")
    unauthenticated_public_response = test_unauthenticated_endpoint(config)
    unauthenticated_auth_response = test_unauthenticated_auth_endpoint(config)

    # Ask user which Cognito authentication method to test
    print("\nAuthenticated Cognito Options:")
    print("1. Password Authentication")
    if PYCOGNITO_AVAILABLE:
        print("2. SRP Authentication (more secure)")
        print("3. Skip authenticated Cognito testing")
        max_choice = "3"
    else:
        print("2. Skip authenticated Cognito testing")
        print("   (SRP auth not available - install 'pycognito' for more options)")
        max_choice = "2"

    choice = (
        input(f"Choose authenticated Cognito method (1-{max_choice}): ").lower().strip()
    )
    cognito_response = None

    match choice:
        case "1":
            cognito_response = test_cognito_auth_endpoint(config)
        case "2" if PYCOGNITO_AVAILABLE:
            cognito_response = test_cognito_srp_auth(config)
        case "3" if PYCOGNITO_AVAILABLE:
            print("Skipping authenticated Cognito testing")
        case "2" if not PYCOGNITO_AVAILABLE:
            print("Skipping authenticated Cognito testing")
        case _:
            print("Invalid choice, skipping authenticated Cognito testing")

    # Summary
    print("\nSUMMARY:")
    print(
        f"Plain endpoint (no auth): {'✓ SUCCESS' if plain_response and plain_response.status_code == 200 else '✗ FAILED'}"
    )
    print(
        f"IAM auth endpoint: {'✓ SUCCESS' if iam_auth_response and iam_auth_response.status_code == 200 else '✗ FAILED'}"
    )
    print(
        f"Unauthenticated /test/public: {'✓ SUCCESS' if unauthenticated_public_response and unauthenticated_public_response.status_code == 200 else '✗ FAILED'}"
    )
    print(
        f"Unauthenticated /test/auth (expect 403): {'✓ SUCCESS' if unauthenticated_auth_response is not None and unauthenticated_auth_response.status_code == 403 else '✗ FAILED'}"
    )
    if cognito_response is not None:
        auth_method = "SRP" if choice in ["2", "4"] else "Password"
        print(
            f"Authenticated Cognito {auth_method}: {'✓ SUCCESS' if cognito_response.status_code == 200 else '✗ FAILED'}"
        )


if __name__ == "__main__":
    main()
