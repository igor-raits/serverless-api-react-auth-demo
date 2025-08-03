#!/bin/bash

# Build and deploy script for React app
set -e

# Configuration
AWS_PROFILE="${AWS_PROFILE:-default}"
DEBUG_MODE="${DEBUG:-false}"

# Check for debug flag
if [ "$1" = "--debug" ] || [ "$1" = "-d" ]; then
    DEBUG_MODE="true"
    echo "🐛 Debug mode enabled"
fi

echo "🔧 Getting Terraform outputs..."
echo "📋 Using AWS Profile: $AWS_PROFILE"

# Get outputs from terraform
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_client_id)
IDENTITY_POOL_ID=$(terraform output -raw cognito_identity_pool_id)
OAUTH_DOMAIN=$(terraform output -raw cognito_hosted_ui_domain)
API_ENDPOINT=$(terraform output -raw api_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_distribution_domain_name)
AWS_REGION=$(terraform output -raw cognito_region)
S3_REGIONAL_DOMAIN=$(terraform output -raw s3_bucket_regional_domain_name)

# Validate required outputs
if [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$S3_BUCKET" ]; then
    echo "❌ Error: Missing required Terraform outputs. Make sure 'terraform apply' has been run successfully."
    exit 1
fi

echo "📋 Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Identity Pool ID: $IDENTITY_POOL_ID"
echo "  OAuth Domain: $OAUTH_DOMAIN"
echo "  API Endpoint: $API_ENDPOINT"
echo "  S3 Bucket: $S3_BUCKET"
echo "  CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "  AWS Region: $AWS_REGION"

# Navigate to React app directory
cd react-app

echo "📦 Installing dependencies..."
npm install

echo "🔨 Building React app with configuration..."
# Set environment variables for build (Vite uses VITE_ prefix)
export VITE_USER_POOL_ID="$USER_POOL_ID"
export VITE_USER_POOL_CLIENT_ID="$CLIENT_ID"
export VITE_IDENTITY_POOL_ID="$IDENTITY_POOL_ID"
export VITE_OAUTH_DOMAIN="$OAUTH_DOMAIN.auth.$AWS_REGION.amazoncognito.com"
export VITE_API_ENDPOINT="$API_ENDPOINT"
export VITE_AWS_REGION="$AWS_REGION"
export VITE_REDIRECT_SIGN_IN="https://$CLOUDFRONT_DOMAIN/callback"
export VITE_REDIRECT_SIGN_OUT="https://$CLOUDFRONT_DOMAIN/"
export VITE_DEBUG="$DEBUG_MODE"

echo "🔧 Build configuration:"
echo "  Debug mode: $DEBUG_MODE"

# Build the app
npm run build

echo "☁️ Deploying to S3..."
# Sync build folder to S3
aws s3 sync build/ s3://$S3_BUCKET/ --delete --profile $AWS_PROFILE

# echo "🔄 Creating CloudFront invalidation..."
# # Get CloudFront distribution ID using the exact domain from Terraform
# DISTRIBUTION_ID=$(aws cloudfront list-distributions --profile $AWS_PROFILE --query "DistributionList.Items[?Origins.Items[0].DomainName=='$S3_REGIONAL_DOMAIN'].Id" --output text)

# if [ ! -z "$DISTRIBUTION_ID" ]; then
#     aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*" --profile $AWS_PROFILE
#     echo "✅ CloudFront invalidation created for distribution: $DISTRIBUTION_ID"
# else
#     echo "⚠️ Could not find CloudFront distribution ID"
# fi

echo ""
echo "🎉 Deployment complete!"
echo "🌍 Your app is available at: https://$CLOUDFRONT_DOMAIN"
echo "🔐 Managed Login domain: https://$OAUTH_DOMAIN.auth.$AWS_REGION.amazoncognito.com"
if [ "$DEBUG_MODE" = "true" ]; then
    echo "🐛 Debug logging is ENABLED - check browser console for detailed logs"
fi
echo ""
echo "📝 Next steps:"
echo "1. Create a user in the Cognito User Pool"
echo "2. Visit your app URL and test the authentication flow"
echo "3. Check the JWT tokens and API calls"
echo "4. Customize the Managed Login branding in AWS Console"
echo ""
echo "💡 Usage tips:"
echo "  • Deploy with debug: ./build-and-deploy.sh --debug"
echo "  • Deploy production: ./build-and-deploy.sh"
