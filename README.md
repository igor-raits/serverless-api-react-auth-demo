# Serverless API + React Authentication Demo

A comprehensive demonstration of **AWS API Gateway authentication with Amazon Cognito**, featuring a React web application and Python testing scripts. This project showcases a **modern, secure, and highly extensible serverless architecture** with multiple authentication methods and demonstrates the complete OAuth flow.

This architecture is designed to be **production-ready** and can easily be extended with **federated identity providers** like Okta, Auth0, PingFederation, and other SAML/OIDC providers through Cognito's flexible identity federation capabilities.

## 🏗️ Architecture Overview

This demo implements a full-stack serverless application with:

- **Frontend**: React 19 + Vite SPA hosted on CloudFront + S3
- **Backend**: AWS API Gateway HTTP API with Lambda functions
- **Authentication**: Amazon Cognito User Pool + Identity Pool
- **Authorization**: AWS IAM roles for fine-grained access control
- **Testing**: Python scripts for comprehensive API testing

### Architecture Benefits

✅ **Serverless**: No server management, automatic scaling, pay-per-use<br>
✅ **Secure**: JWT-based authentication with AWS IAM authorization<br>
✅ **Scalable**: Handles millions of users with Cognito and API Gateway<br>
✅ **Cost-Effective**: Pay only for actual usage, not idle resources<br>
✅ **Global**: CloudFront CDN for worldwide low-latency access<br>
✅ **Extensible**: Easy integration with enterprise identity providers<br>
✅ **Maintainable**: Infrastructure as Code with Terraform<br>
✅ **Observable**: Built-in AWS monitoring and logging capabilities

### Authentication Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   React App     │    │   Cognito User   │    │  Cognito        │
│                 │    │   Pool           │    │  Identity Pool  │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         │ 1. OAuth redirect      │                       │
         ├───────────────────────►│                       │
         │                        │                       │
         │ 2. ID + Access tokens  │                       │
         │◄───────────────────────┤                       │
         │                        │                       │
         │ 3. Exchange ID token   │                       │
         │ for AWS credentials    │                       │
         ├────────────────────────┼──────────────────────►│
         │                        │                       │
         │ 4. Temporary AWS creds │                       │
         │◄───────────────────────┼───────────────────────┤
         │                        │                       │
┌─────────────────┐                                       │
│   API Gateway   │                                       │
│                 │                                       │
└─────────────────┘                                       │
         │                                                │
         │ 5. API call with SigV4 + X-Cognito-Id-Token    │
         │◄───────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **AWS CLI** configured with appropriate credentials
- **Terraform** >= 1.0
- **Node.js** >= 18
- **Python** >= 3.11 (for testing scripts - requires modern union syntax and match statements)

### 1. Clone and Configure

```bash
git clone https://github.com/igor-raits/serverless-api-react-auth-demo
cd serverless-api-react-auth-demo

# Copy and configure Terraform variables
cp terraform.auto.tfvars.example terraform.auto.tfvars
```

### 2. Configure Terraform Variables

Edit `terraform.auto.tfvars`:

```hcl
# AWS Configuration
aws_region  = "us-east-1"           # Your preferred AWS region
aws_profile = "your-profile-name"   # Your AWS CLI profile

# CORS Configuration (optional)
# Add localhost for local development
# apigw_cors_allow_origins_extra = ["http://localhost:3000", "http://localhost:5173"]
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment (optional but recommended)
terraform plan

# Deploy all resources
terraform apply
```

This creates:
- Cognito User Pool and Identity Pool
- API Gateway HTTP API with Lambda backend
- S3 bucket and CloudFront distribution
- IAM roles and policies

### 4. Deploy React Application

```bash
# Build and deploy React app
./build-and-deploy.sh
```

The script will:
- Extract Terraform outputs
- Install npm dependencies
- Build React app with proper environment variables
- Deploy to S3 and CloudFront

### 5. Create Cognito Users

```bash
# Use the user management script
./manage-users.sh
```

Choose option **1** to create a new user, then **2** to set a permanent password.

### 6. Test the Application

**Web Interface:**
Visit the CloudFront domain URL (shown after deployment) to test the React app.

**Python Testing Scripts:**
```bash
# Install testing dependencies (optional)
pip install pycognito boto3 requests

# Run comprehensive API tests
python test_auth.py
```

## 📁 Project Structure

```
├── terraform.auto.tfvars.example   # Terraform configuration template
├── providers.tf                    # Terraform providers
├── variables.tf                    # Terraform variables
├── cognito.tf                     # Cognito User/Identity Pools
├── apigw.tf                       # API Gateway + Lambda
├── fe.tf                          # S3 + CloudFront frontend
├── outputs.tf                     # Terraform outputs
├── lambda_function.py             # Lambda backend code
├── build-and-deploy.sh            # React deployment script
├── manage-users.sh                # Cognito user management
├── test_auth.py                   # Python API testing script
└── react-app/
    ├── index.html                 # Main HTML template
    ├── package.json               # Node.js dependencies
    ├── vite.config.js             # Vite build configuration
    └── src/
        ├── index.jsx              # React app entry point
        ├── index.css              # Global styles
        ├── App.jsx                # Main React component
        ├── CallbackPage.jsx       # OAuth callback handler
        └── config.js              # AWS Amplify configuration
```

## 🔐 Authorization Architecture Layers

This demo showcases a **multi-layered authorization architecture** that progresses from completely public access to fine-grained user-specific permissions:

### Layer 1: API Endpoints and Their Requirements

The demo includes three endpoints that demonstrate different authorization patterns:

**`GET /test/plain`**
- **Requirement:** None - completely public
- **Access:** Anyone on the internet
- **Use Case:** Health checks, public documentation, marketing pages

**`GET /test/public`**
- **Requirement:** Valid AWS credentials (any AWS IAM user/role)
- **Access:** Anyone with AWS credentials that have `execute-api:Invoke` permission
- **Use Case:** Semi-public APIs that need basic AWS authentication but not user identity

**`GET /test/auth`**
- **Requirement:** AWS credentials obtained through Cognito authentication flow
- **Access:** Users who have authenticated via Cognito and obtained AWS credentials
- **Use Case:** User-specific APIs that need identity context and authorization

### Layer 2: IAM Roles and Assignment Logic

**The Cognito Identity Pool** acts as a credential broker, exchanging Cognito tokens for temporary AWS credentials mapped to specific IAM roles:

#### Role Assignment Hierarchy

**1. Unauthenticated Role**
- **When assigned:** When requesting AWS credentials without providing any Cognito tokens
- **Typical permissions:** Very limited - only specific "public" endpoints
- **Example access:** Can call `/test/public` but not `/test/auth`

**2. Default Authenticated Role**
- **When assigned:** When providing valid Cognito User Pool tokens but no specific group mapping applies
- **Typical permissions:** Standard user access to most application endpoints
- **Example access:** Can call both `/test/public` and `/test/auth`

**3. Group-Mapped Roles**
- **When assigned:** When user belongs to specific Cognito groups (Admin, Viewer, etc.)
- **Role selection:** Identity Pool examines `cognito:groups` claim in JWT and maps to specialized roles
- **Typical permissions:** Role-specific access patterns

#### Group-to-Role Mapping Logic

The Identity Pool can be configured with **mapping rules** that examine JWT claims and assign different IAM roles:

**Mapping Rule Priority:**
1. Check if user has `cognito:groups` containing "Admin" → Assign Admin IAM role
2. Check if user has `cognito:groups` containing "Viewer" → Assign Viewer IAM role
3. Fallback to default authenticated role

**Real-World Scenario:**
```
User authenticates → JWT contains "cognito:groups": ["Admin"]
                  → Identity Pool sees "Admin" group
                  → Maps to Admin IAM role with elevated permissions
                  → User can now access admin-only endpoints
```

#### Role Permission Examples

**Admin Role Permissions:**
- All API Gateway endpoints (`execute-api:Invoke` on `*/*/*`)
- Full database operations (`dynamodb:GetItem`, `dynamodb:Query`, `dynamodb:PutItem`, `dynamodb:DeleteItem`)
- Complete S3 access (`s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`)

**Viewer Role Permissions:**
- Read-only API endpoints (`execute-api:Invoke` on `*/*/GET/*`)
- Database read operations (`dynamodb:GetItem`, `dynamodb:Query`)
- S3 object reading (`s3:GetObject`)

**Standard Authenticated Role Permissions:**
- Most API endpoints except admin-specific ones
- User-scoped database operations
- User-scoped S3 access

### Layer 3: Group Priority and Precedence

**Cognito Groups** have a **precedence value** that determines which group takes priority when a user belongs to multiple groups:

**Group Precedence Example:**
- Admin group: precedence = 0 (highest priority)
- Manager group: precedence = 10
- Viewer group: precedence = 99 (lowest priority)

**Multi-Group Scenario:**
```
User belongs to: ["Manager", "Viewer"]
→ Identity Pool sees both groups
→ "Manager" has higher precedence (lower number)
→ User gets Manager IAM role permissions
```

### Layer 4: Fine-Grained Authorization via JWT Parsing

**Beyond IAM:** Once inside the Lambda function, you can parse the JWT token for **user-specific authorization** that goes beyond what IAM roles can provide.

#### JWT Token Structure

```json
{
  "sub": "12345678-1234-1234-1234-123456789012",
  "email": "user@example.com",
  "cognito:groups": ["Admin", "ProjectManager"],
  "cognito:username": "user@example.com"
}
```

**Note:** Custom attributes like `custom:department` or `custom:project_ids` can be configured in the Cognito User Pool and automatically mapped from federated identity providers (Okta, Auth0, etc.). This enables department-based or project-based authorization patterns.

#### Lambda Authorization Patterns

**Pattern 1: Resource Ownership**
```python
def check_resource_access(jwt_payload, resource_id):
    user_id = jwt_payload.get("sub")

    # Check if user owns the resource
    resource = get_resource(resource_id)
    if resource.owner_id == user_id:
        return True

    # Check group-based override
    user_groups = jwt_payload.get("cognito:groups", [])
    if "Admin" in user_groups:
        return True

    return False
```

**Pattern 2: Department-Based Access**
```python
def check_department_access(jwt_payload, resource_id):
    user_dept = jwt_payload.get("custom:department")  # Requires User Pool custom attribute

    resource = get_resource(resource_id)
    return resource.department == user_dept
```

**Pattern 3: Project-Based Access**
```python
def check_project_access(jwt_payload, resource_id):
    user_projects = jwt_payload.get("custom:project_ids", "").split(",")  # Custom attribute

    resource = get_resource(resource_id)
    return resource.project_id in user_projects
```

### Dynamic Group Assignment (Optional Extension)

**Cognito Hooks for Advanced Scenarios:** You can use Cognito Lambda triggers to dynamically assign groups during user lifecycle events. This is **purely optional** and not required for the demo, but shows the extensibility:

```python
# Pre Token Generation Lambda trigger (optional advanced pattern)
def lambda_handler(event, context):
    # Handle token generation events where group assignment is needed
    # TokenGeneration_HostedAuth: Cognito Hosted UI sign-in (includes federated providers)
    # TokenGeneration_Authentication: Direct API authentication flows
    if event["triggerSource"] in {"TokenGeneration_HostedAuth", "TokenGeneration_Authentication"}:

        user_pool_id = event["userPoolId"]
        username = event["userName"]

        # Extract user attributes (from federated identity or custom attributes)
        user_attributes = event["request"].get("userAttributes", {})
        department = user_attributes.get("custom:department", "")

        # Simple mapping: Engineering department gets Developer group
        if department == "Engineering":
            # Copy existing group configuration to preserve current groups
            group_config = event["request"].get("groupConfiguration", {})
            existing_groups = group_config.get("groupsToOverride", [])

            # Add Developer group if not already present
            if "Developer" not in existing_groups:
                # Assign to Developer group (which maps to Developer IAM role in Identity Pool)
                cognito_client.admin_add_user_to_group(
                    UserPoolId=user_pool_id,
                    Username=username,
                    GroupName="Developer",
                )

                # Copy the entire group configuration and add the new group
                updated_group_config = group_config.copy()
                updated_group_config["groupsToOverride"] = existing_groups + ["Developer"]

                # Update the current token being generated
                event["response"]["claimsOverrideDetails"] = {
                    "groupOverrideDetails": updated_group_config,
                }

        # Note: Identity Pool will later map 'Developer' group to Developer IAM role
        # when user requests AWS credentials for API calls

    return event
```

**Use Cases for Dynamic Assignment:**
- **Federated Identity Mapping**: Map `custom:department` from external identity providers to Cognito groups (e.g., Engineering → Developer group)
- **Conditional Access**: Assign groups based on user attributes during first authentication
- **Zero Manual Setup**: Users get proper permissions immediately without admin intervention
- **Identity Provider Integration**: Works seamlessly with any SAML/OIDC provider that sends department/role attributes

### Authorization Flow Summary

```
Internet Request
       ↓
┌─────────────────┐
│ 1. API Gateway  │ ← Public endpoints (no auth required)
│    Endpoint     │
└─────────────────┘
       ↓
┌─────────────────┐
│ 2. IAM Auth     │ ← AWS credentials validation
│    Validation   │   • Any AWS creds for /test/public
└─────────────────┘   • Cognito-issued creds for /test/auth
       ↓
┌─────────────────┐
│ 3. Role-Based   │ ← IAM role permissions check
│    IAM Policy   │   • Unauthenticated → limited access
└─────────────────┘   • Authenticated → broader access
       ↓               • Group-mapped → specialized access
┌─────────────────┐
│ 4. Lambda       │ ← JWT parsing for user-specific logic
│    Fine-Grained │   • Resource ownership checks
└─────────────────┘   • Custom attribute validation
       ↓               • Business rule enforcement
┌─────────────────┐
│ 5. Business     │ ← Your application logic
│    Logic        │
└─────────────────┘
```

The architecture provides multiple authorization layers from public access to fine-grained user-specific permissions.

## 🔧 Lambda Function Purpose

The `lambda_function.py` serves as a **demonstration backend** that showcases how to:

- **Extract user information** from the custom `X-Cognito-Id-Token` header
- **Decode JWT tokens** without verification (for demo purposes)
- **Parse Cognito groups** (`Admin`, `Viewer`) for role-based access control
- **Handle both authenticated and unauthenticated** requests gracefully
- **Return detailed debugging information** including:
  - User identity details (username, email, sub, etc.)
  - Group memberships and authorization flags
  - API Gateway request context
  - AWS credentials context (Identity Pool ID)

**Sample Lambda Response:**
```json
{
  "message": "Hello from Lambda!",
  "user_info": {
    "username": "user@example.com",
    "email": "user@example.com",
    "sub": "12345678-1234-1234-1234-123456789012"
  },
  "user_groups": ["Admin"],
  "is_admin": true,
  "is_viewer": false,
  "api_info": {
    "api_id": "abc123xyz",
    "stage": "$default",
    "request_id": "12345678-1234-1234-1234-123456789012"
  }
}
```

This pattern demonstrates how to build **stateless, secure APIs** that can make authorization decisions based on user identity and group membership.

## 🔐 Role-Based Access Control (RBAC) Implementation

This architecture provides a foundation for implementing RBAC by combining **Cognito groups** (coarse-grained) with **user.userId-based permissions** (fine-grained):

### The Two-Layer Authorization Model

**Layer 1: Cognito Groups (Application-Level Roles)**
- **What**: Broad application roles (`Admin`, `Viewer`, `Manager`, `Editor`)
- **Where**: Stored in JWT token as `cognito:groups` claim
- **Used for**: Feature access, UI visibility, API endpoint authorization
- **Performance**: Fast - no database lookup required

**Layer 2: User Permissions (Resource-Level Access)**
- **What**: Specific resource ownership and granular permissions
- **Where**: Stored in DynamoDB or other database, keyed by `user.userId` (Cognito `sub`)
- **Used for**: Document ownership, team memberships, custom business rules
- **Performance**: Single database query per authorization check

### Integration Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Gateway   │    │   Lambda API     │    │   DynamoDB      │
│   (AWS IAM)     │    │   Function       │    │   Permissions   │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         │ 1. Request +           │                       │
         │ X-Cognito-Id-Token     │                       │
         ├───────────────────────►│                       │
         │                        │ 2. Extract groups     │
         │                        │ from JWT token        │
         │                        │                       │
         │                        │ 3. Query user perms   │
         │                        │ by user.userId        │
         │                        ├──────────────────────►│
         │                        │                       │
         │                        │ 4. Permission data    │
         │                        │◄──────────────────────┤
         │                        │                       │
         │ 5. API response        │                       │
         │◄───────────────────────┤                       │
```

**Note:** API Gateway still uses **AWS IAM authorization** - the Lambda function is your regular API endpoint that simply checks permissions as part of its business logic.

### How Components Work Together

**1. Cognito Groups Handle High-Level Access:**
```python
# In Lambda function - extract from JWT (no DB query)
user_groups = jwt_payload.get("cognito:groups", [])

# Quick feature access decisions
if "Admin" in user_groups:
    return allow_all_access()
if "Viewer" in user_groups and request_method == "GET":
    return continue_to_resource_check()
```

**2. DynamoDB Handles Fine-Grained Permissions:**
```python
# Query by user.userId for resource-specific permissions
user_id = jwt_payload.get("sub")  # Cognito user ID
permissions = dynamodb.get_item(
    Key={"user_id": user_id, "resource_id": resource_id}
)

# Business logic decisions
if permissions.get("owner") == user_id:
    return allow_access()
if user_id in permissions.get("collaborators", []):
    return allow_read_only()
```

### DynamoDB Permission Store Design

**Why DynamoDB is Perfect for This:**
- **Fast lookups** by `user_id` and `resource_id`
- **Schema flexibility** for evolving permission structures
- **Serverless** - fits the architecture perfectly
- **Global Secondary Indexes** for querying by resource or team
- **TTL support** for temporary permissions

**Key Access Patterns:**
```python
# Pattern 1: User's permissions on specific resource
{
    "user_id": "user-123",           # Partition key
    "resource_id": "doc-456",        # Sort key
    "permissions": ["read", "write"],
    "granted_by": "admin-789",
    "expires_at": 1234567890
}

# Pattern 2: Team memberships (using GSI)
{
    "user_id": "user-123",
    "team_id": "team-abc",           # GSI partition key
    "role": "manager",
    "resource_type": "team_membership"
}
```

### Lambda Authorization Flow

**Simple Integration Example:**
```python
def lambda_handler(event, context):
    # Step 1: Extract user info from custom header
    user_info, user_groups = get_user_info_from_token(event)

    # Step 2: Quick group-based checks (no DB query needed)
    if "Admin" in user_groups:
        # Admin can access everything - proceed with full business logic
        return handle_admin_request(event, user_info)

    # Step 3: Resource-specific authorization (DynamoDB query if needed)
    resource_id = event["pathParameters"].get("id")
    user_id = user_info["sub"]

    has_permission = check_user_permission(user_id, resource_id, "read")

    if has_permission or "Manager" in user_groups:
        return handle_authorized_request(event, user_info)
    else:
        return {"statusCode": 403, "body": "Access denied"}

def check_user_permission(user_id, resource_id, action):
    # Single DynamoDB query for fine-grained permissions
    response = dynamodb.get_item(
        Key={"user_id": user_id, "resource_id": resource_id}
    )
    permissions = response.get("Item", {}).get("permissions", [])
    return action in permissions

def handle_authorized_request(event, user_info):
    # Your actual business logic here
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Success!",
            "data": get_user_specific_data(user_info["sub"])
        })
    }
```

### Real-World Usage Examples

**Document Management System:**
- **Cognito Groups**: `Editor` can create documents, `Viewer` can only read
- **User Permissions**: Each document has specific collaborators beyond group rules
- **Integration**: Check group first (fast), then document ownership (DynamoDB)

**Multi-Tenant Application:**
- **Cognito Groups**: `OrgAdmin` manages organization, `User` accesses resources
- **User Permissions**: Each user belongs to specific organizations and projects
- **Integration**: Group defines scope, DynamoDB defines which orgs/projects

### Integration Benefits

1. **Performance**: Group checks are instant, permission checks are single queries
2. **Scalability**: Cognito handles millions of users, DynamoDB scales permissions independently
3. **Flexibility**: Add new groups without DB changes, add new permissions without Cognito changes
4. **Maintainability**: Clear separation between broad roles and specific permissions
5. **Cost-Effective**: Only query DynamoDB when needed, leverage JWT caching

The architecture separates concerns between coarse-grained group permissions and fine-grained resource permissions.

## 🔑 The X-Cognito-Id-Token Header Explained

The `X-Cognito-Id-Token` header is a **custom implementation** used in this demo to pass user context to the Lambda function:

### Why Use This Header?

1. **User Information**: API Gateway's IAM authorization only validates AWS credentials but doesn't provide user details
2. **Group Membership**: The ID token contains Cognito groups (`Admin`, `Viewer`) for authorization logic
3. **User Context**: Enables personalized responses based on user attributes

### How It Works

```javascript
// React app sends both SigV4 auth AND custom header
headers['Authorization'] = 'AWS4-HMAC-SHA256 ...'  // SigV4 signature
headers['X-Cognito-Id-Token'] = tokens.idToken     // JWT with user info
```

```python
# Lambda function extracts user info from the custom header
def get_user_info_from_token(event):
    headers = event.get("headers", {})
    id_token = headers.get("x-cognito-id-token")  # Case insensitive

    # Decode JWT to extract user info and groups
    payload = decode_jwt_payload(id_token)
    user_groups = payload.get("cognito:groups", [])

    return user_info, user_groups
```

### Security Considerations

- The JWT signature should be **verified in production** (this demo skips verification for simplicity)
- The custom header is in addition to, not instead of, proper AWS authentication
- Consider using API Gateway JWT authorizers for production scenarios

## 🛠️ API Endpoints

| Endpoint | Authorization | Access Level | Description |
|----------|---------------|--------------|-------------|
| `GET /test/plain` | None | Public | No authentication required |
| `GET /test/public` | AWS IAM | Unauthenticated role | Requires Identity Pool credentials |
| `GET /test/auth` | AWS IAM | Authenticated role | Requires User Pool authentication |

### IAM Policy Differences

**Unauthenticated Role:**
```json
{
  "Effect": "Allow",
  "Action": "execute-api:Invoke",
  "Resource": "arn:aws:execute-api:*/*/GET/test/public"
}
```

**Authenticated Role:**
```json
{
  "Effect": "Allow",
  "Action": "execute-api:Invoke",
  "Resource": "arn:aws:execute-api:*/*/*"
}
```

## 🧪 Testing Scenarios

The `test_auth.py` script demonstrates multiple authentication patterns:

### 1. No Authentication
```bash
curl https://your-api-gateway.execute-api.us-east-1.amazonaws.com/test/plain
```

### 2. AWS IAM with User Credentials
```python
# Uses your AWS CLI profile credentials
session = boto3.Session(profile_name=AWS_PROFILE)
credentials = session.get_credentials()
# Signs request with SigV4
```

### 3. Cognito Password Authentication
```python
cognito_client.initiate_auth(
    ClientId=client_id,
    AuthFlow="USER_PASSWORD_AUTH",
    AuthParameters={"USERNAME": username, "PASSWORD": password}
)
```

### 4. Cognito SRP Authentication (Optional)
```python
# Requires 'pycognito' library
pip install pycognito

# More secure than password auth
u = Cognito(user_pool_id, client_id, username=username)
u.authenticate(password=password)
```

### 5. Unauthenticated Cognito Identity
```python
# Gets temporary AWS credentials without authentication
identity_response = cognito_identity.get_id(
    IdentityPoolId=identity_pool_id
    # No Logins parameter = unauthenticated
)
```

## 👥 User Management

### Creating Users

Use the `manage-users.sh` script for user management:

```bash
./manage-users.sh
```

Options available:
1. **Create new user** - Creates user with temporary password
2. **Set permanent password** - Updates user to permanent password
3. **List all users** - Shows all users and their status
4. **Add user to group** - Assigns users to `Admin` or `Viewer` groups
5. **Delete user** - Removes user from pool

### Manual User Creation

```bash
# Create user via AWS CLI
aws cognito-idp admin-create-user \
  --user-pool-id "us-east-1_XXXXXXXXX" \
  --username "user@example.com" \
  --user-attributes Name=email,Value="user@example.com" Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id "us-east-1_XXXXXXXXX" \
  --username "user@example.com" \
  --password "NewPassword123!" \
  --permanent
```

## 🔧 Configuration Details

### Environment Variables (React App)

The `build-and-deploy.sh` script automatically sets these during build:

```bash
export VITE_USER_POOL_ID="us-east-1_XXXXXXXXX"
export VITE_USER_POOL_CLIENT_ID="XXXXXXXXXXXXXXXXXXXXXXXXXX"
export VITE_IDENTITY_POOL_ID="us-east-1:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
export VITE_OAUTH_DOMAIN="your-domain.auth.us-east-1.amazoncognito.com"
export VITE_API_ENDPOINT="https://api-id.execute-api.us-east-1.amazonaws.com"
export VITE_AWS_REGION="us-east-1"
export VITE_REDIRECT_SIGN_IN="https://cloudfront-domain/callback"
export VITE_REDIRECT_SIGN_OUT="https://cloudfront-domain/"
```

### Cognito Configuration

**User Pool Settings:**
- Username attributes: Email
- Password policy: Simplified for demo (6 chars minimum)
- Groups: `Admin` (precedence 0), `Viewer` (precedence 99)
- OAuth flows: Authorization code flow
- Managed Login: Version 2 (modern Hosted UI)

**Identity Pool Settings:**
- Unauthenticated access: Enabled
- Authentication providers: Cognito User Pool
- IAM roles: Separate roles for authenticated/unauthenticated

## 🌐 Federation & Extensibility

This architecture supports federated identity providers such as Okta, Auth0, PingFederation, Azure AD, and other SAML/OIDC providers through Cognito's identity federation capabilities.

### Federation Capabilities

1. **Single Sign-On (SSO)**: Users authenticate once across all corporate applications
2. **Centralized User Management**: Leverage existing corporate directories
3. **Multi-Organization Support**: Mix and match providers for unified login across multiple companies or business units
4. **Compliance**: Meet enterprise security and audit requirements
5. **Zero-Trust Architecture**: Fine-grained access control through IAM policies
6. **Scalability**: Handle millions of users across multiple identity sources

The architecture supports enterprise authentication patterns through Cognito's federation capabilities.

## 🚀 Production Considerations

### Security Enhancements

1. **JWT Verification**: Implement proper JWT signature verification in Lambda
2. **Password Policy**: Strengthen password requirements
3. **MFA**: Enable multi-factor authentication
4. **Advanced Security**: Enable Cognito advanced security features
5. **Custom Certificates**: Set up custom SSL certificates and ensure TLS 1.2+ for enhanced security
6. **Rate Limiting**: Implement API Gateway throttling and usage plans
7. **Input Validation**: Add comprehensive input validation in Lambda functions

### Monitoring & Logging

1. **CloudWatch**: Monitor API Gateway and Lambda metrics
2. **CloudTrail**: Track authentication events
3. **WAF**: Add Web Application Firewall for additional protection

## 🐛 Troubleshooting

### Common Issues

**"Missing required Terraform outputs"**
- Ensure `terraform apply` completed successfully
- Check AWS credentials and permissions

**"CORS errors in browser"**
- Check API Gateway CORS configuration
- Verify CloudFront domain is in allowed origins

**"403 Forbidden from API"**
- Verify user is in correct Cognito group
- Check IAM policies for authenticated/unauthenticated roles
- Ensure Identity Pool is configured correctly

**"Python syntax errors in test_auth.py"**
- Ensure you're using Python 3.11+ (required for `| None` union syntax and `match` statements)
- Update Python: `python --version` should show 3.11 or higher

### Debug Steps

1. **Check Terraform outputs:**
   ```bash
   terraform output
   ```

2. **Test API endpoints manually:**
   ```bash
   python test_auth.py
   ```

3. **Verify Cognito configuration:**
   ```bash
   aws cognito-idp describe-user-pool --user-pool-id <pool-id>
   ```

4. **Check browser console for detailed error messages**

## 📚 Learn More

- [AWS Cognito User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html)
- [AWS Cognito Identity Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/identity-pools.html)
- [API Gateway IAM Authentication](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html)
- [AWS Amplify Authentication](https://docs.amplify.aws/javascript/build-a-backend/auth/)
- [JWT.io](https://jwt.io/) - JWT token decoder

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is released into the public domain under [The Unlicense](LICENSE).
