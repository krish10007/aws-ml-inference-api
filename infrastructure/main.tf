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

module "s3" {
  source = "./modules/s3"

  bucket_name  = "${var.project_name}-model-artifacts-${var.environment}"
  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source = "./modules/iam"

  project_name               = var.project_name
  environment                = var.environment
  model_artifacts_bucket_arn = module.s3.bucket_arn
  sagemaker_endpoint_arn     = module.sagemaker.endpoint_arn
}

module "lambda" {
  source = "./modules/lambda"

  project_name              = var.project_name
  environment               = var.environment
  sagemaker_endpoint_name   = module.sagemaker.endpoint_name
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
  artifacts_bucket_name     = module.s3.bucket_name   # ADD THIS LINE
}

module "sagemaker" {
  source = "./modules/sagemaker"

  project_name                 = var.project_name
  environment                  = var.environment
  aws_region                   = var.aws_region
  model_artifacts_bucket_name  = module.s3.bucket_name
  sagemaker_execution_role_arn = module.iam.sagemaker_execution_role_arn
}

module "api_gateway" {
  source = "./modules/api_gateway"

  project_name          = var.project_name
  environment           = var.environment
  lambda_invoke_arn     = module.lambda.invoke_arn
  lambda_function_name  = module.lambda.function_name
}

module "sns" {
  source = "./modules/sns"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  sagemaker_endpoint_name = module.sagemaker.endpoint_name
  sns_topic_arn           = module.sns.topic_arn
}