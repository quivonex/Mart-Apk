import boto3
import uuid
from django.conf import settings


def upload_file_to_s3(file, folder="agreements"):
    """
    Upload file to S3 and return file key + URL
    """

    s3 = boto3.client(
        's3',
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.AWS_S3_REGION_NAME
    )

    try:
        # Generate unique file name
        file_extension = file.name.split('.')[-1]
        file_name = f"{folder}/{uuid.uuid4()}.{file_extension}"

        # Upload file
        s3.upload_fileobj(
            file,
            settings.AWS_STORAGE_BUCKET_NAME,
            file_name,
            ExtraArgs={'ContentType': file.content_type}
        )

        # Generate URL
        file_url = f"https://{settings.AWS_STORAGE_BUCKET_NAME}.s3.amazonaws.com/{file_name}"

        return {
            "key": file_name,
            "url": file_url
        }

    except Exception as e:
        print("S3 Upload Error:", str(e))
        return None