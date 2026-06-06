variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "model_artifacts_bucket_name" {
  description = "Name of the S3 bucket containing model artifacts"
  type        = string
}

variable "sagemaker_execution_role_arn" {
  description = "ARN of the IAM role SageMaker uses to access S3"
  type        = string
}