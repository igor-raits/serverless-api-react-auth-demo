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
  description = "Additional origins to allow for CORS (e.g., localhost for development)"
  type        = list(string)
  default     = []
}

variable "cognito_callback_urls_extra" {
  description = "Additional OAuth callback URLs (e.g., http://localhost:5173/callback for development)"
  type        = list(string)
  default     = []
}

variable "cognito_logout_urls_extra" {
  description = "Additional OAuth logout URLs (e.g., http://localhost:5173/ for development)"
  type        = list(string)
  default     = []
}
