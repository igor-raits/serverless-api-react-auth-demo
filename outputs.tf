# Backend API

output "api_endpoint" {
  value = module.api_gateway.api_endpoint
}

# Frontend app

output "s3_bucket_name" {
  value = module.s3_bucket.s3_bucket_id
}

output "cloudfront_distribution_domain_name" {
  value = module.cloudfront.cloudfront_distribution_domain_name
}

# Auth

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.default.id
}

output "cognito_identity_pool_id" {
  value = aws_cognito_identity_pool.this.id
}

output "cognito_hosted_ui_domain" {
  value = aws_cognito_user_pool_domain.this.domain
}

output "cognito_region" {
  value = "us-east-1"
}

# Additional outputs for better configuration
output "s3_bucket_regional_domain_name" {
  value = module.s3_bucket.s3_bucket_bucket_regional_domain_name
}
