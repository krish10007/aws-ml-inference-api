output "function_name" {
  value = aws_lambda_function.inference.function_name
}

output "function_arn" {
  value = aws_lambda_function.inference.arn
}

output "invoke_arn" {
  description = "ARN used by API Gateway to invoke this function"
  value       = aws_lambda_function.inference.invoke_arn
}