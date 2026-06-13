data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/package"
  output_path = "${path.root}/../lambda/lambda.zip"
}

resource "aws_s3_object" "lambda_package" {
  bucket = var.artifacts_bucket_name
  key    = "lambda/lambda.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = data.archive_file.lambda_zip.output_md5
}

resource "aws_lambda_function" "inference" {
  function_name    = "${var.project_name}-inference"
  s3_bucket        = aws_s3_object.lambda_package.bucket
  s3_key           = aws_s3_object.lambda_package.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  role             = var.lambda_execution_role_arn
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      SAGEMAKER_ENDPOINT_NAME = var.sagemaker_endpoint_name
      CLOUDWATCH_NAMESPACE    = "MLInferenceAPI"
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_s3_object.lambda_package]
}