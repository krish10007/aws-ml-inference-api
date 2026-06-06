variable "bucket_name" {
  description = "Name of the S3 bucket for model artifacts"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment for tagging"
  type        = string
}