#!/bin/bash

# React app development and deployment script
set -e

# Configuration
AWS_PROFILE="${AWS_PROFILE:-default}"
DEBUG_MODE="${DEBUG:-false}"
DEV_MODE="false"

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "React app development and deployment script for AWS serverless demo"
    echo ""
    echo "OPTIONS:"
    echo "  --dev          Run development server on http://localhost:5173"
    echo "  --debug, -d    Enable debug logging in the React app"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                    # Build and deploy to production"
    echo "  $0 --dev              # Run local development server"
    echo "  $0 --dev --debug      # Run dev server with debug logging"
    echo "  $0 --debug            # Deploy to production with debug logging"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - Terraform must be initialized and applied"
    echo "  - AWS CLI must be configured with appropriate credentials"
    echo "  - Node.js and npm must be installed"
}

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --debug|-d)
            DEBUG_MODE="true"
            ;;
        --dev)
            DEV_MODE="true"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🔧 Getting Terraform outputs..."
echo "📋 Using AWS Profile: $AWS_PROFILE"
if [ "$DEV_MODE" = "true" ]; then
    echo "🚀 Mode: Development Server"
else
    echo "📦 Mode: Build & Deploy"
fi
if [ "$DEBUG_MODE" = "true" ]; then
    echo "🐛 Debug: ENABLED (check browser console for detailed logs)"
fi
echo ""

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
if [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$API_ENDPOINT" ]; then
    echo "❌ Error: Missing required Terraform outputs. Make sure 'terraform apply' has been run successfully."
    exit 1
fi

# Additional validation for deploy mode only
if [ "$DEV_MODE" = "false" ] && [ -z "$S3_BUCKET" ]; then
    echo "❌ Error: S3 bucket is required for deployment. Make sure 'terraform apply' has been run successfully."
    exit 1
fi

echo "📋 Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Identity Pool ID: $IDENTITY_POOL_ID"
echo "  OAuth Domain: $OAUTH_DOMAIN"
echo "  API Endpoint: $API_ENDPOINT"
if [ "$DEV_MODE" = "false" ]; then
    echo "  S3 Bucket: $S3_BUCKET"
fi
echo "  CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "  AWS Region: $AWS_REGION"
echo "  Debug Mode: $DEBUG_MODE"

# Navigate to React app directory
cd react-app

echo "📦 Installing dependencies..."
npm install

# Set environment variables for build/dev (Vite uses VITE_ prefix)
export VITE_USER_POOL_ID="$USER_POOL_ID"
export VITE_USER_POOL_CLIENT_ID="$CLIENT_ID"
export VITE_IDENTITY_POOL_ID="$IDENTITY_POOL_ID"
export VITE_OAUTH_DOMAIN="$OAUTH_DOMAIN.auth.$AWS_REGION.amazoncognito.com"
export VITE_API_ENDPOINT="$API_ENDPOINT"
export VITE_AWS_REGION="$AWS_REGION"
export VITE_DEBUG="$DEBUG_MODE"

# Set redirect URLs based on mode
if [ "$DEV_MODE" = "true" ]; then
    export VITE_REDIRECT_SIGN_IN="http://localhost:5173/callback"
    export VITE_REDIRECT_SIGN_OUT="http://localhost:5173/"
else
    export VITE_REDIRECT_SIGN_IN="https://$CLOUDFRONT_DOMAIN/callback"
    export VITE_REDIRECT_SIGN_OUT="https://$CLOUDFRONT_DOMAIN/"
fi

# Development mode - run dev server and exit
if [ "$DEV_MODE" = "true" ]; then
    echo ""
    echo "🚀 Starting development server..."
    echo "🌍 Local app: http://localhost:5173"
    echo "🔐 OAuth redirects: http://localhost:5173/callback"
    echo ""

    # Run the development server
    npm run dev
    exit 0
fi

echo "🔨 Building React app..."

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
echo ""
echo "📝 Next steps:"
echo "1. Create a user in the Cognito User Pool"
echo "2. Visit your app URL and test the authentication flow"
echo "3. Check the JWT tokens and API calls"
echo "4. Customize the Managed Login branding in AWS Console"
echo ""
echo "💡 Usage tips:"
echo "  • Run dev server: ./run.sh --dev"
echo "  • Run dev with debug: ./run.sh --dev --debug"
echo "  • Deploy with debug: ./run.sh --debug"
echo "  • Deploy production: ./run.sh"
