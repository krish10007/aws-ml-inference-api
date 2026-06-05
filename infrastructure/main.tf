terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "ml-inference-tf-state-krish"
    key            = "ml-inference-api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ml-inference-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}