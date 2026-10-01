# products3_upload.py

import boto3 # type: ignore
from botocore.exceptions import NoCredentialsError # type: ignore
from django.conf import settings # type: ignore
import uuid

# --- S3 Client Setup ---
s3_client = boto3.client(
    's3',
    aws_access_key_id=getattr(settings, 'AWS_ACCESS_KEY_ID', ''),
    aws_secret_access_key=getattr(settings, 'AWS_SECRET_ACCESS_KEY', ''),
    region_name=getattr(settings, 'AWS_REGION', 'ap-south-1')  # default region
)

# Bucket name fix: check AWS_S3_BUCKET_NAME or fallback to AWS_STORAGE_BUCKET_NAME
AWS_BUCKET_NAME = getattr(settings, 'AWS_S3_BUCKET_NAME', getattr(settings, 'AWS_STORAGE_BUCKET_NAME', ''))

def upload_file_to_s3(file, folder='products'):
    """
    फाइल S3 वर upload करून पूर्ण public URL return करते.
    Browser मध्ये direct display साठी ContentType set केले आहे.
    """
    try:
        # File extension आणि unique filename तयार करा
        ext = file.name.split('.')[-1]
        file_name = f"{folder}/{uuid.uuid4()}.{ext}"

        # S3 वर upload (ContentType set)
        s3_client.upload_fileobj(
            file,
            AWS_BUCKET_NAME,
            file_name,
            ExtraArgs={
                'ContentType': file.content_type  # Browser मध्ये display होण्यासाठी
            }
        )

        # Public URL तयार करा
        region = getattr(settings, 'AWS_REGION', 'ap-south-1')
        url = f"https://{AWS_BUCKET_NAME}.s3.{region}.amazonaws.com/{file_name}"
        return url

    except NoCredentialsError:
        print("AWS credentials missing!")
        return None
    except Exception as e:
        print("S3 Upload Error:", e)
        return None