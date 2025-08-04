variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
}

variable "apigw_cors_allow_origins_extra" {
  description = "Additional CORS allowed origins for API Gateway (e.g., http://localhost:5173 for development)"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "cognito_callback_urls_extra" {
  description = "Additional OAuth callback URLs (e.g., http://localhost:5173/callback for development)"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "cognito_logout_urls_extra" {
  description = "Additional OAuth logout URLs (e.g., http://localhost:5173/ for development)"
  type        = list(string)
  default     = []
  nullable    = false
}
