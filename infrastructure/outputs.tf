output "model_artifacts_bucket_name" {
  description = "S3 bucket for model artifacts"
  value       = module.s3.bucket_name
}

output "model_artifacts_bucket_arn" {
  description = "ARN of model artifacts S3 bucket"
  value       = module.s3.bucket_arn
}