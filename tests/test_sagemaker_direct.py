"""
Test the SageMaker endpoint directly — before Lambda exists.
Sends a real image and prints the top 5 predictions.
"""

import os
import json
import numpy as np
import boto3
from PIL import Image
import tensorflow as tf

ENDPOINT_NAME = os.environ["SAGEMAKER_ENDPOINT_NAME"]
IMAGE_PATH    = "test_dog.jpg"


def preprocess_image(image_path: str) -> list:
    """Resize, normalize, and convert image to list for JSON serialization."""
    img = Image.open(image_path).convert("RGB")
    img = img.resize((224, 224))
    arr = np.array(img, dtype=np.float32)
    arr = tf.keras.applications.mobilenet_v2.preprocess_input(arr)
    return arr.tolist()   # SageMaker JSON input must be a plain list


def main():
    client = boto3.client("sagemaker-runtime", region_name="us-east-1")

    print(f"Preprocessing {IMAGE_PATH}...")
    payload = {"instances": [preprocess_image(IMAGE_PATH)]}

    print(f"Invoking endpoint: {ENDPOINT_NAME}")
    response = client.invoke_endpoint(
        EndpointName=ENDPOINT_NAME,
        ContentType="application/json",
        Body=json.dumps(payload),
    )

    result = json.loads(response["Body"].read())
    predictions = np.array(result["predictions"][0])

    # Decode top 5 ImageNet predictions
    decoded = tf.keras.applications.mobilenet_v2.decode_predictions(
        predictions.reshape(1, -1), top=5
    )[0]

    print("\nTop 5 predictions:")
    for i, (class_id, class_name, confidence) in enumerate(decoded, 1):
        print(f"  {i}. {class_name:<30} {confidence:.1%}")


if __name__ == "__main__":
    main()