import boto3
import uuid
from django.conf import settings
from botocore.exceptions import NoCredentialsError


def upload_file_to_s3(file, folder):

    try:
        s3_client = boto3.client(
            "s3",
            region_name=settings.AWS_S3_REGION_NAME,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )

        # 🔥 Unique file name
        file_extension = file.name.split('.')[-1]
        unique_filename = f"{uuid.uuid4()}.{file_extension}"

        s3_key = f"{folder}/{unique_filename}"

        s3_client.upload_fileobj(
            file,
            settings.AWS_STORAGE_BUCKET_NAME,
            s3_key,
            ExtraArgs={"ContentType": file.content_type}
        )

        return s3_key

    except NoCredentialsError:
        return None


def delete_file_from_s3(s3_key):

    try:
        s3_client = boto3.client(
            "s3",
            region_name=settings.AWS_S3_REGION_NAME,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )

        s3_client.delete_object(
            Bucket=settings.AWS_STORAGE_BUCKET_NAME,
            Key=s3_key
        )

        return True

    except Exception:
        return False