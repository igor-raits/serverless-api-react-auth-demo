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

## 🔐 Authentication Methods

### 1. No Authentication (`/test/plain`)
- Direct API access without any authentication
- No headers or signatures required

### 2. AWS IAM Authentication (`/test/auth`, `/test/public`)
- Uses AWS Signature Version 4 (SigV4)
- Requires valid AWS credentials
- Different IAM policies for authenticated vs unauthenticated users

### 3. Cognito Authentication
**User Pool Authentication:**
- Username/password or SRP (Secure Remote Password)
- Returns JWT tokens (ID, Access, Refresh)

**Identity Pool Integration:**
- Exchanges User Pool tokens for AWS credentials
- Enables fine-grained IAM permissions

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

This architecture is designed for **enterprise scalability** and can be easily extended with **federated identity providers** such as Okta, Auth0, PingFederation, Azure AD, and other SAML/OIDC providers through Cognito's flexible identity federation capabilities.

### Extension Benefits

1. **Single Sign-On (SSO)**: Users authenticate once across all corporate applications
2. **Centralized User Management**: Leverage existing corporate directories
3. **Multi-Organization Support**: Mix and match providers for unified login across multiple companies or business units
4. **Compliance**: Meet enterprise security and audit requirements
5. **Zero-Trust Architecture**: Fine-grained access control through IAM policies
6. **Scalability**: Handle millions of users across multiple identity sources

This makes the demo a **foundation for enterprise authentication** rather than just a learning exercise.

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
