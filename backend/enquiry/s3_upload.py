import boto3
import uuid

from django.conf import settings
from botocore.exceptions import NoCredentialsError


def upload_file_to_s3(file, folder="uploads"):

    """
    Upload file to AWS S3 bucket
    Returns uploaded file URL
    """

    try:

        # 🔹 S3 Client
        s3_client = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_S3_REGION_NAME
        )

        # 🔹 Unique filename
        extension = file.name.split('.')[-1]

        filename = f"{uuid.uuid4()}.{extension}"

        s3_path = f"{folder}/{filename}"

        # 🔹 Upload file
        s3_client.upload_fileobj(

            file,

            settings.AWS_STORAGE_BUCKET_NAME,

            s3_path,

            ExtraArgs={
                "ContentType": file.content_type
            }
        )

        # 🔹 File URL
        file_url = (
            f"https://{settings.AWS_STORAGE_BUCKET_NAME}.s3."
            f"{settings.AWS_S3_REGION_NAME}.amazonaws.com/{s3_path}"
        )

        return {
            "status": True,
            "file_url": file_url,
            "file_path": s3_path
        }

    except NoCredentialsError:

        return {
            "status": False,
            "message": "AWS credentials not found"
        }

    except Exception as e:

        return {
            "status": False,
            "message": str(e)
        }