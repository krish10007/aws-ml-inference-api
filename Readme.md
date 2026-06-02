# ML Inference API on AWS

A production-grade serverless ML inference API that classifies images using MobileNetV2 deployed on AWS SageMaker.

## Architecture

_Diagram coming after full build._

## Stack

- **Model**: MobileNetV2 (ImageNet, 1000 classes)
- **Inference**: AWS SageMaker real-time endpoint
- **API**: AWS API Gateway → AWS Lambda (Python 3.11)
- **IaC**: Terraform with S3 remote state
- **Observability**: CloudWatch custom metrics, alarms, dashboard
- **CI/CD**: GitHub Actions with OIDC (keyless AWS auth)

## Benchmarks

_Real numbers coming after load testing._

| Metric | Result |
|--------|--------|
| p50 latency | TBD |
| p95 latency | TBD |
| p99 latency | TBD |
| Cost @ 100k req/mo | TBD |

## Quick Start

```bash
# Coming after full build
```

## Example Request

```bash
curl -X POST https://<your-endpoint>/classify \
  -H "Content-Type: application/json" \
  -d '{"image_url": "https://example.com/dog.jpg"}'
```