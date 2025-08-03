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
