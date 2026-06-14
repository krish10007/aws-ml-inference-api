output "api_endpoint" {
  description = "Base URL of the API Gateway"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "classify_url" {
  description = "Full URL for the POST /classify endpoint"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/classify"
}