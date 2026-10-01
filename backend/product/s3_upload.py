# s3_upload.py

import boto3 # type: ignore
import uuid
from django.conf import settings # type: ignore
from urllib.parse import urlparse


def upload_to_s3(file_obj):

    s3 = boto3.client(
        "s3",
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.AWS_REGION,
    )

    file_name = f"products/{uuid.uuid4()}.png"

    s3.upload_fileobj(
        file_obj,
        settings.AWS_STORAGE_BUCKET_NAME,
        file_name,
        ExtraArgs={"ContentType": "image/png"}
    )

    return file_name


from io import BytesIO
from django.core.files.uploadedfile import InMemoryUploadedFile

def clone_file(file):
    file_content = file.read()
    return InMemoryUploadedFile(
        file=BytesIO(file_content),
        field_name=file.field_name,
        name=file.name,
        content_type=file.content_type,
        size=len(file_content),
        charset=None
    )

def delete_s3_file(file_url):
    s3_client = boto3.client(
        "s3",
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.AWS_REGION,
    )

    try:
        if not file_url:
            return False

        # --------------------------
        # 🔥 Extract key from URL
        # --------------------------
        parsed_url = urlparse(file_url)

        # Example:
        # https://bucket.s3.ap-south-1.amazonaws.com/products/images/abc.jpg
        # → key = products/images/abc.jpg

        key = parsed_url.path.lstrip("/")

        # --------------------------
        # 🔥 Delete from S3
        # --------------------------
        s3_client.delete_object(
            Bucket=settings.AWS_STORAGE_BUCKET_NAME,
            Key=key
        )

        print(f"Deleted from S3: {key}")
        return True

    except Exception as e:
        print("S3 Delete Error:", str(e))
        return False