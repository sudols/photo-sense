import boto3
import os
from functools import lru_cache

BUCKET = os.getenv("S3_BUCKET_NAME")


@lru_cache(maxsize=1)
def _get_s3_client():
    return boto3.client("s3", region_name=os.getenv("AWS_REGION", "ap-south-1"))


def upload_to_s3(file_bytes, s3_key, content_type="image/jpeg"):
    _get_s3_client().put_object(
        Bucket=BUCKET, Key=s3_key, Body=file_bytes, ContentType=content_type
    )


def delete_from_s3(s3_key):
    _get_s3_client().delete_object(Bucket=BUCKET, Key=s3_key)


def get_presigned_url(s3_key, expiry_seconds=604800):  # 7 days
    return _get_s3_client().generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": s3_key},
        ExpiresIn=expiry_seconds,
    )
