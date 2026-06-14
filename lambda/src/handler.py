"""
Lambda handler for ML Inference API.
Receives an image URL, preprocesses the image, invokes SageMaker,
and returns the top prediction with confidence score.
"""

import os
import io
import json
import time
import logging
import urllib.request
import urllib.error

import boto3
import numpy as np
from PIL import Image

# ── Logging ──────────────────────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ── Environment variables (set via Terraform) ────────────────────────────────
SAGEMAKER_ENDPOINT_NAME = os.environ["SAGEMAKER_ENDPOINT_NAME"]
CLOUDWATCH_NAMESPACE    = os.environ.get("CLOUDWATCH_NAMESPACE", "MLInferenceAPI")
AWS_REGION              = os.environ.get("AWS_REGION", "us-east-1")

# ── AWS clients (initialised outside handler for connection reuse) ────────────
sagemaker_runtime = boto3.client("sagemaker-runtime", region_name=AWS_REGION)
cloudwatch        = boto3.client("cloudwatch",         region_name=AWS_REGION)


# ── Helpers ───────────────────────────────────────────────────────────────────

def build_response(status_code: int, body: dict) -> dict:
    """Build a consistent API Gateway response."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def push_metric(metric_name: str, value: float, unit: str) -> None:
    """Push a single custom metric to CloudWatch. Failures are logged, not raised."""
    try:
        cloudwatch.put_metric_data(
            Namespace=CLOUDWATCH_NAMESPACE,
            MetricData=[{
                "MetricName": metric_name,
                "Value":      value,
                "Unit":       unit,
                "Dimensions": [
                    {"Name": "EndpointName", "Value": SAGEMAKER_ENDPOINT_NAME}
                ],
            }],
        )
    except Exception as e:
        logger.warning("Failed to push metric %s: %s", metric_name, e)


def download_image(image_url: str) -> Image.Image:
    """Download image from URL and return as PIL Image."""
    try:
        with urllib.request.urlopen(image_url, timeout=10) as response:
            image_data = response.read()
        return Image.open(io.BytesIO(image_data)).convert("RGB")
    except urllib.error.URLError as e:
        raise ValueError(f"Could not download image from URL: {e.reason}") from e
    except Exception as e:
        raise ValueError(f"Invalid image data at URL: {e}") from e


def preprocess_image(image: Image.Image) -> list:
    """Resize to 224x224, apply MobileNetV2 normalisation, return as nested list."""
    image = image.resize((224, 224))
    arr   = np.array(image, dtype=np.float32)

    # MobileNetV2 expects pixels normalised to [-1, 1]
    arr = (arr / 127.5) - 1.0

    return arr.tolist()


def invoke_sagemaker(payload: dict) -> np.ndarray:
    """Send preprocessed image to SageMaker and return raw prediction array."""
    response = sagemaker_runtime.invoke_endpoint(
        EndpointName=SAGEMAKER_ENDPOINT_NAME,
        ContentType="application/json",
        Body=json.dumps(payload),
    )
    result      = json.loads(response["Body"].read())
    predictions = np.array(result["predictions"][0])
    return predictions

# ImageNet class index — top 1000 labels
IMAGENET_LABELS_URL = (
    "https://storage.googleapis.com/download.tensorflow.org"
    "/data/imagenet_class_index.json"
)

_imagenet_labels: dict = {}

def _load_imagenet_labels() -> dict:
    """Lazily load ImageNet labels. Cached after first call."""
    global _imagenet_labels
    if _imagenet_labels:
        return _imagenet_labels
    with urllib.request.urlopen(IMAGENET_LABELS_URL, timeout=10) as r:
        data = json.loads(r.read())
    # data: {"0": ["n01440764", "tench"], ...}
    _imagenet_labels = {int(k): v[1] for k, v in data.items()}
    return _imagenet_labels


def decode_predictions(predictions: np.ndarray) -> tuple:
    """Return top predicted class name and confidence without TensorFlow."""
    labels     = _load_imagenet_labels()
    top_index  = int(np.argmax(predictions))
    confidence = float(predictions[top_index])
    class_name = labels.get(top_index, f"class_{top_index}")
    return class_name, confidence


# ── Main handler ──────────────────────────────────────────────────────────────

def lambda_handler(event, context):
    """
    Expected input:
        POST /classify
        {"image_url": "https://example.com/dog.jpg"}

    Success response (200):
        {"class": "Labrador_retriever", "confidence": 0.256}

    Error responses:
        400 — missing or invalid input
        502 — SageMaker invocation failed
    """
    push_metric("InvocationCount", 1, "Count")
    start_time = time.monotonic()

    # ── 1. Parse and validate input ───────────────────────────────────────────
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        push_metric("ErrorCount", 1, "Count")
        return build_response(400, {"error": "Request body must be valid JSON"})

    image_url = body.get("image_url", "").strip()
    if not image_url:
        push_metric("ErrorCount", 1, "Count")
        return build_response(400, {"error": "Missing required field: image_url"})

    if not image_url.startswith(("http://", "https://")):
        push_metric("ErrorCount", 1, "Count")
        return build_response(400, {"error": "image_url must be a valid HTTP/HTTPS URL"})

    # ── 2. Download and preprocess ────────────────────────────────────────────
    try:
        logger.info("Downloading image from %s", image_url)
        image              = download_image(image_url)
        preprocessed       = preprocess_image(image)
        sagemaker_payload  = {"instances": [preprocessed]}
    except ValueError as e:
        push_metric("ErrorCount", 1, "Count")
        return build_response(400, {"error": str(e)})

    # ── 3. Invoke SageMaker ───────────────────────────────────────────────────
    try:
        logger.info("Invoking SageMaker endpoint: %s", SAGEMAKER_ENDPOINT_NAME)
        sm_start     = time.monotonic()
        predictions  = invoke_sagemaker(sagemaker_payload)
        sm_latency   = (time.monotonic() - sm_start) * 1000   # ms

        push_metric("SageMakerLatencyMs", sm_latency, "Milliseconds")
        logger.info("SageMaker latency: %.1fms", sm_latency)

    except Exception as e:
        logger.error("SageMaker invocation failed: %s", e)
        push_metric("ErrorCount", 1, "Count")
        return build_response(502, {"error": "Inference service unavailable"})

    # ── 4. Decode and return ──────────────────────────────────────────────────
    try:
        class_name, confidence = decode_predictions(predictions)
    except Exception as e:
        logger.error("Prediction decoding failed: %s", e)
        push_metric("ErrorCount", 1, "Count")
        return build_response(502, {"error": "Failed to decode model predictions"})

    total_latency = (time.monotonic() - start_time) * 1000
    push_metric("InferenceLatencyMs", total_latency, "Milliseconds")
    logger.info("Total latency: %.1fms | Class: %s | Confidence: %.3f",
                total_latency, class_name, confidence)

    return build_response(200, {
        "class":      class_name,
        "confidence": round(confidence, 4),
    })# trigger ci
# CI/CD pipeline verified
