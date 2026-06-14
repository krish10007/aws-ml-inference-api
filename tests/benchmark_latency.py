"""
Latency benchmark for ML Inference API.

Sends N sequential requests to the /classify endpoint using a fixed
test image, records round-trip latency for each, and computes
p50/p95/p99 statistics.
"""

import time
import json
import statistics
import requests

# ── Configuration ─────────────────────────────────────────────────────────────
API_URL    = "https://ng2if800ke.execute-api.us-east-1.amazonaws.com/classify"
IMAGE_URL  = "https://images.dog.ceo/breeds/coonhound/n02089078_933.jpg"
NUM_REQUESTS = 25
DELAY_BETWEEN_REQUESTS = 0.5  # seconds — be polite to the endpoint


def run_benchmark():
    latencies = []
    errors    = 0

    print(f"Sending {NUM_REQUESTS} requests to {API_URL}")
    print(f"Test image: {IMAGE_URL}\n")

    for i in range(1, NUM_REQUESTS + 1):
        payload = {"image_url": IMAGE_URL}

        start = time.perf_counter()
        try:
            response = requests.post(API_URL, json=payload, timeout=30)
            elapsed_ms = (time.perf_counter() - start) * 1000

            if response.status_code == 200:
                body = response.json()
                latencies.append(elapsed_ms)
                print(f"Request {i:2d}: {elapsed_ms:7.1f} ms  |  "
                      f"{body.get('class', '?')} ({body.get('confidence', 0):.2%})")
            else:
                errors += 1
                print(f"Request {i:2d}: FAILED  |  status={response.status_code}  "
                      f"body={response.text}")

        except requests.exceptions.RequestException as e:
            errors += 1
            print(f"Request {i:2d}: ERROR  |  {e}")

        time.sleep(DELAY_BETWEEN_REQUESTS)

    return latencies, errors


def percentile(data: list, pct: float) -> float:
    """Compute the pct-th percentile using linear interpolation."""
    sorted_data = sorted(data)
    k = (len(sorted_data) - 1) * (pct / 100)
    f = int(k)
    c = min(f + 1, len(sorted_data) - 1)
    if f == c:
        return sorted_data[f]
    return sorted_data[f] + (sorted_data[c] - sorted_data[f]) * (k - f)


def print_summary(latencies: list, errors: int):
    total = len(latencies) + errors

    print("\n" + "=" * 50)
    print("LATENCY SUMMARY")
    print("=" * 50)
    print(f"Total requests : {total}")
    print(f"Successful     : {len(latencies)}")
    print(f"Errors         : {errors}")
    print(f"Error rate     : {errors / total * 100:.1f}%")

    if latencies:
        print(f"\nMin            : {min(latencies):7.1f} ms")
        print(f"Mean           : {statistics.mean(latencies):7.1f} ms")
        print(f"p50 (median)   : {percentile(latencies, 50):7.1f} ms")
        print(f"p95            : {percentile(latencies, 95):7.1f} ms")
        print(f"p99            : {percentile(latencies, 99):7.1f} ms")
        print(f"Max            : {max(latencies):7.1f} ms")


def save_results(latencies: list, errors: int, filepath: str = "tests/benchmark_results.json"):
    results = {
        "total_requests": len(latencies) + errors,
        "successful": len(latencies),
        "errors": errors,
        "latencies_ms": latencies,
        "p50_ms": round(percentile(latencies, 50), 2) if latencies else None,
        "p95_ms": round(percentile(latencies, 95), 2) if latencies else None,
        "p99_ms": round(percentile(latencies, 99), 2) if latencies else None,
        "mean_ms": round(statistics.mean(latencies), 2) if latencies else None,
        "min_ms": round(min(latencies), 2) if latencies else None,
        "max_ms": round(max(latencies), 2) if latencies else None,
    }

    with open(filepath, "w") as f:
        json.dump(results, f, indent=2)

    print(f"\nResults saved to {filepath}")


if __name__ == "__main__":
    latencies, errors = run_benchmark()
    print_summary(latencies, errors)
    save_results(latencies, errors)