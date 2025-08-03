resource "aws_cognito_user_pool" "this" {
  name = "igorovo"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Very simple password policy for testing
  password_policy {
    minimum_length    = 6
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  # Simplified for demo - uncomment for production security
  # user_pool_add_ons {
  #   advanced_security_mode = "ENFORCED"
  # }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_user_group" "admin" {
  user_pool_id = aws_cognito_user_pool.this.id

  name       = "Admin"
  precedence = 0
}

resource "aws_cognito_user_group" "viewer" {
  user_pool_id = aws_cognito_user_pool.this.id

  name       = "Viewer"
  precedence = 99
}

resource "aws_cognito_user_pool_client" "default" {
  user_pool_id = aws_cognito_user_pool.this.id

  name = "default"

  # OAuth settings for Managed Login (modern replacement for deprecated Hosted UI)
  generate_secret = false
  callback_urls   = ["https://${module.cloudfront.cloudfront_distribution_domain_name}/callback"]
  logout_urls     = ["https://${module.cloudfront.cloudfront_distribution_domain_name}/"]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  # Enable advanced security features available in Managed Login
  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  access_token_validity  = 60 # 1 hour
  id_token_validity      = 60 # 1 hour
  refresh_token_validity = 7  # 7 days

  explicit_auth_flows = [
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]
}

resource "awscc_cognito_managed_login_branding" "default" {
  user_pool_id = aws_cognito_user_pool.this.id
  client_id    = aws_cognito_user_pool_client.default.id

  use_cognito_provided_values = true
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "igorovo-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.this.id

  # Use Managed Login (modern replacement for deprecated Hosted UI)
  managed_login_version = 2
}

resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

data "aws_iam_policy_document" "authenticated" {
  statement {
    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values   = [aws_cognito_identity_pool.this.id]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values   = ["authenticated"]
    }
  }
}

resource "aws_iam_role" "authenticated" {
  name               = "IgorovoAuthenticated"
  path               = "/igorovo/"
  assume_role_policy = data.aws_iam_policy_document.authenticated.json
}

data "aws_iam_policy_document" "authenticated_policy" {
  statement {
    actions   = ["cognito-identity:GetCredentialsForIdentity"]
    resources = ["*"]
  }

  statement {
    actions = ["execute-api:Invoke"]
    resources = [
      "${module.api_gateway.api_execution_arn}/*/*",
    ]
  }
}

resource "aws_iam_role_policy" "authenticated" {
  name_prefix = "IgorovoAuthenticatedPolicy"
  role        = aws_iam_role.authenticated.id
  policy      = data.aws_iam_policy_document.authenticated_policy.json
}

data "aws_iam_policy_document" "unauthenticated" {
  statement {
    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values   = [aws_cognito_identity_pool.this.id]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values   = ["unauthenticated"]
    }
  }
}

resource "aws_iam_role" "unauthenticated" {
  name               = "IgorovoUnauthenticated"
  path               = "/igorovo/"
  assume_role_policy = data.aws_iam_policy_document.unauthenticated.json
}

data "aws_iam_policy_document" "unauthenticated_policy" {
  statement {
    actions   = ["cognito-identity:GetCredentialsForIdentity"]
    resources = ["*"]
  }

  statement {
    actions = ["execute-api:Invoke"]
    resources = [
      "${module.api_gateway.api_execution_arn}/*/GET/test/public",
    ]
  }
}

resource "aws_iam_role_policy" "unauthenticated" {
  name_prefix = "IgorovoUnauthenticatedPolicy"
  role        = aws_iam_role.unauthenticated.id
  policy      = data.aws_iam_policy_document.unauthenticated_policy.json
}

resource "aws_cognito_identity_pool" "this" {
  identity_pool_name               = "igorovo"
  allow_unauthenticated_identities = true

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.default.id
    provider_name = aws_cognito_user_pool.this.endpoint
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "this" {
  identity_pool_id = aws_cognito_identity_pool.this.id

  roles = {
    "authenticated"   = aws_iam_role.authenticated.arn
    "unauthenticated" = aws_iam_role.unauthenticated.arn
  }
}
