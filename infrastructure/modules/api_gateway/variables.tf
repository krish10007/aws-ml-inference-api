variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function (for API Gateway integration)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function (for resource-based permission)"
  type        = string
}