# ── HTTP API (cheaper and simpler than REST API for this use case) ───────────

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Integration — connects API Gateway to the Lambda function ────────────────

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"

  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

# ── Route — defines POST /classify ────────────────────────────────────────────

resource "aws_apigatewayv2_route" "classify" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /classify"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# ── Stage — deploys the API and gives it a public URL ─────────────────────────

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Permission — allows API Gateway to invoke the Lambda function ─────────────

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}