variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "model_artifacts_bucket_arn" {
  description = "ARN of the S3 bucket containing model artifacts"
  type        = string
}