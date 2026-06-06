variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "model_artifacts_bucket_arn" {
  type = string
}

variable "sagemaker_endpoint_arn" {
  description = "ARN of the SageMaker endpoint Lambda is allowed to invoke"
  type        = string
}