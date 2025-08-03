module "api_gateway" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-apigateway-v2.git?ref=v5.3.0"

  name          = "IgorovoAPI"
  protocol_type = "HTTP"

  create_domain_name = false

  # Enable CORS for browser requests from React app
  cors_configuration = {
    allow_headers = [
      "content-type",
      "authorization",      # For 'Bearer <jwt-token>' from Cognito
      "x-cognito-id-token", # Custom header used in your API calls
      # AWS signature headers for IAM auth
      "x-amz-date",
      "x-amz-security-token",
      "x-amz-user-agent",
    ]
    allow_methods = ["GET", "POST", "OPTIONS"] # OPTIONS required for CORS preflight
    allow_origins = concat(
      ["https://${module.cloudfront.cloudfront_distribution_domain_name}"],
      var.apigw_cors_allow_origins_extra,
    )
    expose_headers    = ["date"]
    max_age           = 86400
    allow_credentials = false # False because we use Authorization header, not cookies
  }

  routes = {
    "GET /test/plain" = {
      authorization_type = "NONE"
      integration = {
        uri                    = module.test_function.lambda_function_arn
        payload_format_version = "2.0"
      }
    }
    "GET /test/auth" = {
      authorization_type = "AWS_IAM"
      integration = {
        uri                    = module.test_function.lambda_function_arn
        payload_format_version = "2.0"
      }
    }
    "GET /test/public" = {
      authorization_type = "AWS_IAM"
      integration = {
        uri                    = module.test_function.lambda_function_arn
        payload_format_version = "2.0"
      }
    }
  }
}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function.zip"
}

module "test_function" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git?ref=v8.0.1"

  function_name = "IgorovoTestFunction"
  handler       = "lambda_function.handler"
  runtime       = "python3.13"
  architectures = ["arm64"]
  publish       = true

  create_package         = false
  local_existing_package = data.archive_file.lambda_package.output_path

  # Set to false when using publish = true for better production practices
  create_current_version_allowed_triggers = false

  allowed_triggers = {
    AllowExecutiongFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.api_execution_arn}/*/*"
    }
  }
}
