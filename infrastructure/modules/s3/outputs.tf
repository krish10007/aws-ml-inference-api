output "bucket_name" {
  description = "Name of the model artifacts S3 bucket"
  value       = aws_s3_bucket.model_artifacts.bucket
}

output "bucket_arn" {
  description = "ARN of the model artifacts S3 bucket"
  value       = aws_s3_bucket.model_artifacts.arn
}