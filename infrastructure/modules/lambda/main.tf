# ── Package the Lambda zip ───────────────────────────────────────────────────

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/package"
  output_path = "${path.root}/../lambda/lambda.zip"
}

# ── Lambda function ──────────────────────────────────────────────────────────

resource "aws_lambda_function" "inference" {
  function_name    = "${var.project_name}-inference"
  filename         = data.archive_file.lambda_zip.output_path
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
}