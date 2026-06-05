variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for naming and tagging resources"
  type        = string
  default     = "ml-inference-api"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}