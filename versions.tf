terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Fill in `bucket` with the bootstrap output `state_bucket_name` before running this in CI.
  # Local `terraform init`/`plan` without a configured backend still works for learning/dry runs —
  # Terraform will just use local state until you uncomment this.
  # backend "s3" {
  #   bucket         = "static-site-cicd-tfstate-<your-account-id>"
  #   key            = "static-site-cicd/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "static-site-cicd-tfstate-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "portfolio"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
