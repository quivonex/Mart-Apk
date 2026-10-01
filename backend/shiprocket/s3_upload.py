import boto3
import uuid
import os

from django.conf import settings


def upload_video_to_s3(video_file, folder="packing-videos"):
    """
    Upload packing video to AWS S3
    """

    try:
        # File extension
        original_name = video_file.name
        extension = os.path.splitext(original_name)[1].lower()

        # Unique filename
        file_name = f"{folder}/{uuid.uuid4()}{extension}"

        # S3 client
        s3 = boto3.client(
            "s3",
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_S3_REGION_NAME,
        )

        # Upload
        s3.upload_fileobj(
            video_file,
            settings.AWS_STORAGE_BUCKET_NAME,
            file_name,
            ExtraArgs={
                "ContentType": video_file.content_type,
            }
        )

        # Generate URL
        region = settings.AWS_S3_REGION_NAME

        if region:
            file_url = (
                f"https://{settings.AWS_STORAGE_BUCKET_NAME}"
                f".s3.{region}.amazonaws.com/{file_name}"
            )
        else:
            file_url = (
                f"https://{settings.AWS_STORAGE_BUCKET_NAME}"
                f".s3.amazonaws.com/{file_name}"
            )

        return file_url

    except Exception as e:
        raise Exception(f"S3 video upload failed: {str(e)}")