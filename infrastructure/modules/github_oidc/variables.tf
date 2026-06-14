variable "project_name" {
  type = string
}

variable "github_repo" {
  description = "GitHub repo in format 'owner/repo'"
  type        = string
}

variable "lambda_function_arn" {
  type = string
}

variable "artifacts_bucket_arn" {
  type = string
}