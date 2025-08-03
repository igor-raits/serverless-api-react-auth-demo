#!/bin/bash

# Cognito User Management Script
set -e

# AWS Configuration
AWS_PROFILE="${AWS_PROFILE:-default}"

USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw cognito_region 2>/dev/null || echo "${AWS_REGION:-us-east-1}")

echo "🔧 AWS Configuration:"
echo "  Profile: $AWS_PROFILE"
echo "  Region: $AWS_REGION"
echo ""

if [ -z "$USER_POOL_ID" ]; then
    echo "❌ Error: Could not get User Pool ID from Terraform outputs"
    echo "Make sure you have run 'terraform apply' first"
    exit 1
fi

echo "👥 Cognito User Management"
echo "User Pool ID: $USER_POOL_ID"
echo ""

function create_user() {
    read -p "Enter email address for new user: " email
    read -p "Enter temporary password (min 8 chars, needs uppercase, lowercase, number, special char): " temp_password

    echo "Creating user..."
    aws cognito-idp admin-create-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$email" \
        --user-attributes Name=email,Value="$email" Name=email_verified,Value=true \
        --temporary-password "$temp_password" \
        --message-action SUPPRESS \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION"

    echo "✅ User created successfully!"
    echo "📧 Email: $email"
    echo "🔑 Temporary password: $temp_password"
    echo "⚠️ User will need to change password on first login"
}

function set_permanent_password() {
    read -p "Enter user email: " email
    read -p "Enter new permanent password: " new_password

    echo "Setting permanent password..."
    aws cognito-idp admin-set-user-password \
        --user-pool-id "$USER_POOL_ID" \
        --username "$email" \
        --password "$new_password" \
        --permanent \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION"

    echo "✅ Password set successfully!"
}

function list_users() {
    echo "📋 Current users:"
    aws cognito-idp list-users \
        --user-pool-id "$USER_POOL_ID" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'Users[*].[Username,Attributes[?Name==`email`].Value|[0],UserStatus,Enabled]' \
        --output table
}

function add_user_to_group() {
    read -p "Enter user email: " email
    echo "Available groups: Admin, Viewer"
    read -p "Enter group name: " group_name

    aws cognito-idp admin-add-user-to-group \
        --user-pool-id "$USER_POOL_ID" \
        --username "$email" \
        --group-name "$group_name" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION"

    echo "✅ User added to group $group_name"
}

function delete_user() {
    read -p "Enter user email to delete: " email
    read -p "Are you sure? (y/N): " confirm

    if [[ $confirm == [yY] ]]; then
        aws cognito-idp admin-delete-user \
            --user-pool-id "$USER_POOL_ID" \
            --username "$email" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION"

        echo "✅ User deleted successfully!"
    else
        echo "❌ Operation cancelled"
    fi
}

echo "Choose an option:"
echo "1. Create new user"
echo "2. Set permanent password for user"
echo "3. List all users"
echo "4. Add user to group"
echo "5. Delete user"
echo "6. Exit"

read -p "Enter your choice (1-6): " choice

case $choice in
    1) create_user ;;
    2) set_permanent_password ;;
    3) list_users ;;
    4) add_user_to_group ;;
    5) delete_user ;;
    6) echo "Goodbye!" ;;
    *) echo "Invalid choice" ;;
esac
