terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1, >= 1.51.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "awscc" {
  region  = var.aws_region
  profile = var.aws_profile
}
