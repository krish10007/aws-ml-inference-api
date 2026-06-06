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