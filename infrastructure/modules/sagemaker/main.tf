# ── SageMaker Model ──────────────────────────────────────────────────────────

resource "aws_sagemaker_model" "mobilenetv2" {
  name               = "${var.project_name}-mobilenetv2"
  execution_role_arn = var.sagemaker_execution_role_arn

  primary_container {
    # AWS deep learning container for TensorFlow inference (CPU)
    image = "763104351884.dkr.ecr.${var.aws_region}.amazonaws.com/tensorflow-inference:2.13-cpu"

    model_data_url = "s3://${var.model_artifacts_bucket_name}/mobilenetv2/model.tar.gz"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Endpoint Configuration ───────────────────────────────────────────────────

resource "aws_sagemaker_endpoint_configuration" "mobilenetv2" {
  name = "${var.project_name}-mobilenetv2-config"

  production_variants {
    variant_name           = "default"
    model_name             = aws_sagemaker_model.mobilenetv2.name
    initial_instance_count = 1
    instance_type          = "ml.t2.medium"
    initial_variant_weight = 1
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Endpoint ─────────────────────────────────────────────────────────────────

resource "aws_sagemaker_endpoint" "mobilenetv2" {
  name                 = "${var.project_name}-mobilenetv2-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.mobilenetv2.name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}