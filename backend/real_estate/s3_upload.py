import boto3
import uuid
import os
from django.conf import settings
from botocore.exceptions import BotoCoreError, ClientError

s3_client = boto3.client(
    "s3",
    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    region_name=settings.AWS_S3_REGION_NAME
)

def upload_to_s3(file, folder):
    try:
        extension = os.path.splitext(file.name)[1].lower()
        file_name = f"{folder}/{uuid.uuid4().hex}{extension}"

        s3_client.upload_fileobj(
            file,
            settings.AWS_STORAGE_BUCKET_NAME,
            file_name,
            ExtraArgs={
                "ContentType": file.content_type
            }
        )

        file_url = (
            f"https://{settings.AWS_STORAGE_BUCKET_NAME}.s3."
            f"{settings.AWS_S3_REGION_NAME}.amazonaws.com/{file_name}"
        )

        return file_url

    except (BotoCoreError, ClientError) as e:
        raise Exception(f"S3 upload failed: {str(e)}")