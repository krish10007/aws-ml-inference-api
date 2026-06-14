# ML Inference API on AWS

A production-grade, serverless machine learning inference API that classifies images using **MobileNetV2** deployed on **AWS SageMaker**, fronted by **API Gateway** and **Lambda**, fully provisioned with **Terraform**, observable via **CloudWatch**, and deployed automatically through **GitHub Actions with OIDC**.

A user sends an image URL to a public HTTPS endpoint. API Gateway triggers a Lambda function, which downloads and preprocesses the image, invokes a SageMaker real-time endpoint running MobileNetV2, and returns the predicted ImageNet class with a confidence score.

---

## Architecture

```mermaid
flowchart LR
    User[Client] -->|POST /classify| APIGW[API Gateway<br/>HTTP API]
    APIGW --> Lambda[Lambda<br/>preprocess + invoke]
    Lambda -->|invoke_endpoint| SageMaker[SageMaker Endpoint<br/>MobileNetV2 - ml.t2.medium]
    Lambda -->|PutMetricData| CW[CloudWatch<br/>Custom Metrics]
    CW --> Alarms[CloudWatch Alarms<br/>Error Rate / p99 Latency]
    Alarms --> SNS[SNS Topic]
    SNS --> Email[Email Alert]
    CW --> Dashboard[CloudWatch Dashboard<br/>4-panel]
    S3Model[(S3<br/>Model Artifacts)] -.model.tar.gz.-> SageMaker

    GH[GitHub Actions] -->|OIDC, no static keys| AWS_IAM[IAM Role]
    AWS_IAM -->|update-function-code| Lambda
```

**Request flow:** `Client → API Gateway → Lambda → SageMaker → Lambda → API Gateway → Client`

**Deploy flow:** `git push to main → GitHub Actions (OIDC) → package Lambda → upload to S3 → update Lambda code`

---

## Stack

| Layer | Technology |
|---|---|
| Model | MobileNetV2 (ImageNet, 1000 classes), TensorFlow SavedModel |
| Inference | AWS SageMaker real-time endpoint (`ml.t2.medium`) |
| API | AWS API Gateway (HTTP API) → AWS Lambda (Python 3.11) |
| Infrastructure as Code | Terraform, modular, S3 + DynamoDB remote state |
| Observability | CloudWatch custom metrics, alarms, 4-panel dashboard |
| Alerting | SNS (email) |
| CI/CD | GitHub Actions, keyless AWS auth via OIDC |
| Storage | S3 (model artifacts + Lambda deployment packages) |

---

## How It Works

1. **Client** sends `POST /classify` with `{"image_url": "<url>"}`
2. **API Gateway** (HTTP API, `AWS_PROXY` integration) forwards the request to Lambda
3. **Lambda**:
   - Validates the request (missing field, malformed JSON, invalid URL → `400`)
   - Downloads the image and preprocesses it to a `224x224x3` array normalized to `[-1, 1]`
   - Invokes the SageMaker endpoint (`sagemaker-runtime.invoke_endpoint`)
   - Decodes the prediction to a human-readable ImageNet label
   - Pushes custom metrics to CloudWatch (`InvocationCount`, `ErrorCount`, `InferenceLatencyMs`, `SageMakerLatencyMs`)
   - Returns `{"class": "...", "confidence": 0.XX}` (`200`) or an error (`400`/`502`)
4. **SageMaker** runs MobileNetV2 on a pre-built AWS TensorFlow inference container, loaded from a model artifact in S3
5. **CloudWatch** alarms watch error rate (>5%) and p99 latency (>3000ms internal), notifying via **SNS** on breach/recovery
6. **GitHub Actions** repackages and redeploys Lambda automatically on push to `main`, authenticating to AWS via OIDC (no stored credentials)

---

## Example Request

```bash
curl -X POST https://ng2if800ke.execute-api.us-east-1.amazonaws.com/classify \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://images.dog.ceo/breeds/coonhound/n02089078_933.jpg"}'
```

**Response:**

```json
{"class": "black-and-tan_coonhound", "confidence": 0.6671}
```

---

## Benchmarks

Measured across **25 sequential requests** against the live production endpoint, with a fixed test image, 0 errors.

### End-to-end client latency

| Metric | Value |
|---|---|
| p50 (median) | 3,819 ms |
| p95 | 5,605 ms |
| p99 | 7,257 ms |
| Min / Max | 2,621 ms / 7,753 ms |
| Error rate | 0% (25/25) |

### Component-level latency (from CloudWatch / Lambda logs)

| Component | Value |
|---|---|
| SageMaker model inference (avg) | 594 ms |
| SageMaker model inference (max) | 750 ms |
| Total Lambda execution (typical) | 700–900 ms |
| Lambda cold start (init duration, first request only) | +755 ms |

### Diagnosis

The gap between Lambda's internal duration (~800ms) and the client-observed p50 (~3.8s) is **not inference latency** — it's network round-trip and TLS handshake overhead between the client and `us-east-1`, confirmed via `curl`'s timing breakdown (TLS handshake alone accounted for ~2.2s in a sample request). The inference pipeline itself — image preprocessing, SageMaker invocation, and response formatting — consistently completes in under 1 second.

---

## Cost Analysis (100,000 requests/month)

| Service | Estimated Monthly Cost | Notes |
|---|---|---|
| SageMaker (`ml.t2.medium`, 24/7) | **$46.80** | Dominant cost — billed continuously regardless of traffic |
| Lambda (512MB, ~800ms avg) | ~$1.35 | Compute + request charges |
| API Gateway (HTTP API) | ~$0.10 | $1.00 per million requests |
| CloudWatch custom metrics | ~$1.20 | 4 custom metrics |
| S3 / SNS / data transfer | <$1.00 | Negligible at this volume |
| **Total** | **~$50/month** | ~94% driven by the always-on SageMaker endpoint |

**Cost optimization note:** at low-to-moderate request volume, a SageMaker real-time endpoint is the most expensive component by a wide margin because it's billed per hour regardless of usage. For workloads with intermittent traffic, **SageMaker Serverless Inference** or **Lambda-hosted inference** (bundling a lightweight model directly into Lambda) would significantly reduce idle cost at the expense of cold-start latency.

---

## Project Structure

```
aws-ml-inference-api/
├── .github/workflows/
│   └── deploy-lambda.yml       # CI/CD: package + deploy Lambda via OIDC
├── infrastructure/
│   ├── main.tf                 # Root module, wires everything together
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── s3/                 # Model artifacts bucket
│       ├── iam/                # SageMaker + Lambda execution roles
│       ├── sagemaker/          # Model, endpoint config, endpoint
│       ├── lambda/              # Lambda function (S3-based deploy)
│       ├── api_gateway/        # HTTP API + /classify route
│       ├── cloudwatch/         # Alarms + 4-panel dashboard
│       ├── sns/                # Alert topic + email subscription
│       └── github_oidc/        # GitHub Actions IAM role (OIDC trust)
├── lambda/
│   ├── src/handler.py          # Lambda function source
│   └── requirements.txt
├── model/
│   └── scripts/package_model.py # Downloads MobileNetV2, packages for SageMaker
├── tests/
│   ├── test_sagemaker_direct.py
│   ├── benchmark_latency.py
│   └── benchmark_results.json
└── README.md
```

---

## Deployment

### Prerequisites
- AWS account with configured CLI credentials
- Terraform >= 1.6.0
- Python 3.11

### One-time setup

```bash
# 1. Create Terraform remote state backend (S3 + DynamoDB) — one-time, manual
aws s3api create-bucket --bucket <your-tf-state-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <your-tf-state-bucket> --versioning-configuration Status=Enabled
aws dynamodb create-table \
  --table-name <your-tf-lock-table> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# 2. Package and upload the MobileNetV2 model to S3 (bucket created in step 3, run after first apply)
export MODEL_BUCKET_NAME="<your-model-artifacts-bucket>"
python model/scripts/package_model.py
```

### Deploy infrastructure

```bash
cd infrastructure
terraform init
terraform apply
```

Outputs include the public `api_classify_url`, CloudWatch dashboard URL, and SageMaker endpoint name.

### Tear down (cost control)

```bash
# Destroy only the SageMaker endpoint (keeps S3/model artifact + IAM intact)
terraform destroy -target=module.sagemaker

# Full teardown
terraform destroy
```

> **Cost warning:** the SageMaker endpoint bills hourly (~$0.05/hr for `ml.t2.medium`) for as long as it exists. Destroy it when not actively testing.

---

## CI/CD

Pushing changes to `lambda/src/` or `lambda/requirements.txt` on `main` automatically:

1. Builds the Lambda deployment package (`numpy`, `Pillow`)
2. Uploads it to S3 (multipart upload — avoids signature-expiry issues on large packages)
3. Calls `lambda update-function-code`
4. Waits for the update to complete

Authentication uses **GitHub OIDC** — GitHub generates a short-lived signed token per run, which AWS exchanges for temporary credentials scoped to a single IAM role restricted to this repo's `main` branch. No long-lived AWS credentials are stored in GitHub.

---

## Observability

- **Custom metrics** (`MLInferenceAPI` namespace): `InvocationCount`, `ErrorCount`, `InferenceLatencyMs`, `SageMakerLatencyMs`
- **Alarms**:
  - Error rate > 5% (metric math: `ErrorCount / InvocationCount * 100`)
  - p99 `InferenceLatencyMs` > 3000ms
- **Dashboard** (4 panels): Invocation Count, Error Rate %, End-to-End Latency (p50/p95/p99), SageMaker Endpoint Latency (p50/p95/p99)
- **SNS**: email notification on alarm trigger and recovery

---

## Error Handling

| Scenario | Response |
|---|---|
| Missing `image_url` | `400 {"error": "Missing required field: image_url"}` |
| Malformed JSON body | `400 {"error": "Request body must be valid JSON"}` |
| Invalid URL scheme | `400 {"error": "image_url must be a valid HTTP/HTTPS URL"}` |
| Image download failure | `400 {"error": "Could not download image from URL: ..."}` |
| SageMaker invocation failure | `502 {"error": "Inference service unavailable"}` |
| Prediction decode failure | `502 {"error": "Failed to decode model predictions"}` |

---

## Key Engineering Decisions

- **HTTP API over REST API** for API Gateway — ~70% cheaper at scale, sufficient for a single proxy route
- **S3-based Lambda deployment** instead of direct zip upload — avoids AWS's 5-minute request-signature expiry on large packages over slow connections; same pattern used in CI/CD
- **TensorFlow excluded from Lambda** — bundling TensorFlow exceeded Lambda's 250MB unzipped limit; ImageNet label decoding is handled with a lightweight JSON lookup instead of `keras.applications.decode_predictions`
- **`manylinux2014_x86_64` platform tag** for all Lambda dependencies — ensures Linux-compatible binaries regardless of host OS (Windows dev machine)
- **Metric math alarms** — error rate is computed as a ratio of two custom metrics rather than tracked directly, since CloudWatch alarms operate on single metrics or math expressions
- **OIDC over static credentials** — GitHub Actions assumes a tightly-scoped IAM role via short-lived tokens, restricted to `main` branch of this specific repo

---

## Resume Summary

> Built and deployed a production-grade serverless ML inference API on AWS (SageMaker, Lambda, API Gateway) serving MobileNetV2 image classification, with infrastructure fully defined in modular Terraform (remote state, 8 modules). Implemented full observability (CloudWatch custom metrics, alarms, 4-panel dashboard, SNS alerting) and a keyless GitHub Actions CI/CD pipeline via OIDC. Benchmarked the live endpoint across 25 requests with 0% error rate, 594ms average SageMaker inference latency, and performed a full cost analysis projecting ~$50/month at 100k requests.