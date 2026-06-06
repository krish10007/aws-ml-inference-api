"""
Downloads MobileNetV2 pre-trained on ImageNet, saves it in TensorFlow
SavedModel format, packages it as model.tar.gz, and uploads to S3.

SageMaker requires:
  model.tar.gz
  └── 1/
      ├── saved_model.pb
      └── variables/
"""

import os
import tarfile
import boto3
import tensorflow as tf

# ── Configuration ────────────────────────────────────────────────────────────
BUCKET_NAME = os.environ["MODEL_BUCKET_NAME"]   # set before running
MODEL_DIR   = "model/artifacts"                  # local staging directory
TAR_PATH    = "model/model.tar.gz"               # output archive path
S3_KEY      = "mobilenetv2/model.tar.gz"         # where it lands in S3


def download_and_save_model(save_dir: str) -> None:
    """Download MobileNetV2 and save in TensorFlow SavedModel format."""
    print("Downloading MobileNetV2 pre-trained on ImageNet...")

    model = tf.keras.applications.MobileNetV2(
        input_shape=(224, 224, 3),
        alpha=1.0,
        include_top=True,       # include classification head (1000 classes)
        weights="imagenet",     # use pre-trained ImageNet weights
    )

    # SavedModel format requires a version subdirectory — SageMaker expects "1/"
    versioned_path = os.path.join(save_dir, "1")
    os.makedirs(versioned_path, exist_ok=True)

    model.export(versioned_path)
    print(f"Model saved to {versioned_path}")
    print(f"  Parameters : {model.count_params():,}")
    print(f"  Input shape: {model.input_shape}")
    print(f"  Output shape: {model.output_shape}")


def create_tar_gz(source_dir: str, output_path: str) -> None:
    """Package the model directory into model.tar.gz."""
    print(f"\nPackaging {source_dir} → {output_path}")

    with tarfile.open(output_path, "w:gz") as tar:
        # arcname="." means the archive root IS source_dir
        # so inside the tar: 1/saved_model.pb (not artifacts/1/saved_model.pb)
        tar.add(source_dir, arcname=".")

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"Archive size: {size_mb:.1f} MB")


def upload_to_s3(local_path: str, bucket: str, s3_key: str) -> None:
    """Upload model.tar.gz to S3 with a progress indicator."""
    s3 = boto3.client("s3")
    file_size = os.path.getsize(local_path)

    print(f"\nUploading to s3://{bucket}/{s3_key}")

    def progress(bytes_transferred):
        pct = bytes_transferred / file_size * 100
        print(f"  {pct:.1f}%", end="\r")

    s3.upload_file(
        local_path,
        bucket,
        s3_key,
        Callback=progress,
    )
    print(f"\nUpload complete: s3://{bucket}/{s3_key}")


def verify_tar_structure(tar_path: str) -> None:
    """Print the archive contents so you can confirm the structure is correct."""
    print("\nVerifying archive structure:")
    with tarfile.open(tar_path, "r:gz") as tar:
        for member in sorted(tar.getnames()):
            print(f"  {member}")


if __name__ == "__main__":
    # 1. Download and save
    download_and_save_model(MODEL_DIR)

    # 2. Verify local structure before packaging
    print("\nLocal directory structure:")
    for root, dirs, files in os.walk(MODEL_DIR):
        level = root.replace(MODEL_DIR, "").count(os.sep)
        indent = "  " * level
        print(f"{indent}{os.path.basename(root)}/")
        for f in files:
            print(f"{indent}  {f}")

    # 3. Package
    create_tar_gz(MODEL_DIR, TAR_PATH)

    # 4. Verify archive structure — critical check before uploading
    verify_tar_structure(TAR_PATH)

    # 5. Upload
    upload_to_s3(TAR_PATH, BUCKET_NAME, S3_KEY)

    print("\nDone. SageMaker can now access the model at:")
    print(f"  s3://{BUCKET_NAME}/{S3_KEY}")