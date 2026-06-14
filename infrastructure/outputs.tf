output "model_artifacts_bucket_name" {
  value = module.s3.bucket_name
}

output "model_artifacts_bucket_arn" {
  value = module.s3.bucket_arn
}

output "sagemaker_endpoint_name" {
  value = module.sagemaker.endpoint_name
}

output "sagemaker_endpoint_arn" {
  value = module.sagemaker.endpoint_arn
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "api_classify_url" {
  description = "Public URL for the classify endpoint"
  value       = module.api_gateway.classify_url
}

output "sns_topic_arn" {
  value = module.sns.topic_arn
}

output "cloudwatch_dashboard_url" {
  value = module.cloudwatch.dashboard_url
}