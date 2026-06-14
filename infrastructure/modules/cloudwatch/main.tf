# ── Alarm: Error Rate > 5% ─────────────────────────────────────────────────────
#
# CloudWatch doesn't compute "rate" directly — we use a Metric Math expression
# that divides ErrorCount by InvocationCount and multiplies by 100.

resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${var.project_name}-error-rate-high"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5      # percent
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"

  alarm_description = "Triggers when error rate exceeds 5% over a 5-minute window"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  metric_query {
    id          = "error_rate_pct"
    expression  = "(errors / invocations) * 100"
    label       = "ErrorRatePercent"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "MLInferenceAPI"
      metric_name = "ErrorCount"
      period      = 300
      stat        = "Sum"
      dimensions = {
        EndpointName = var.sagemaker_endpoint_name
      }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      namespace   = "MLInferenceAPI"
      metric_name = "InvocationCount"
      period      = 300
      stat        = "Sum"
      dimensions = {
        EndpointName = var.sagemaker_endpoint_name
      }
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Alarm: p99 Latency > 3000ms ────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "latency_p99" {
  alarm_name          = "${var.project_name}-p99-latency-high"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 3000   # milliseconds
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"

  alarm_description = "Triggers when p99 inference latency exceeds 3000ms"
  alarm_actions      = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  namespace   = "MLInferenceAPI"
  metric_name = "InferenceLatencyMs"
  period      = 300
  extended_statistic = "p99"

  dimensions = {
    EndpointName = var.sagemaker_endpoint_name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── 4-Panel Dashboard ────────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Invocation Count"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["MLInferenceAPI", "InvocationCount", "EndpointName", var.sagemaker_endpoint_name, { stat = "Sum", period = 300 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Error Rate (%)"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            [{ expression = "(errors / invocations) * 100", label = "Error Rate %", id = "e1" }],
            ["MLInferenceAPI", "ErrorCount", "EndpointName", var.sagemaker_endpoint_name, { stat = "Sum", period = 300, id = "errors", visible = false }],
            ["MLInferenceAPI", "InvocationCount", "EndpointName", var.sagemaker_endpoint_name, { stat = "Sum", period = 300, id = "invocations", visible = false }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "End-to-End Inference Latency (p50/p95/p99)"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["MLInferenceAPI", "InferenceLatencyMs", "EndpointName", var.sagemaker_endpoint_name, { stat = "p50", period = 300, label = "p50" }],
            ["MLInferenceAPI", "InferenceLatencyMs", "EndpointName", var.sagemaker_endpoint_name, { stat = "p95", period = 300, label = "p95" }],
            ["MLInferenceAPI", "InferenceLatencyMs", "EndpointName", var.sagemaker_endpoint_name, { stat = "p99", period = 300, label = "p99" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "SageMaker Endpoint Latency (p50/p95/p99)"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["MLInferenceAPI", "SageMakerLatencyMs", "EndpointName", var.sagemaker_endpoint_name, { stat = "p50", period = 300, label = "p50" }],
            ["MLInferenceAPI", "SageMakerLatencyMs", "EndpointName", var.sagemaker_endpoint_name, { stat = "p95", period = 300, label = "p95" }],
            ["MLInferenceAPI", "SageMakerLatencyMs", "EndpointName", var.sagemaker_endpoint_name, { stat = "p99", period = 300, label = "p99" }]
          ]
        }
      }
    ]
  })
}