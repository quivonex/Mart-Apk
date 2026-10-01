import boto3
import uuid
import os

from django.conf import settings


# --------------------------------------------------
# AWS S3 CLIENT
# --------------------------------------------------

s3_client = boto3.client(
    "s3",
    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    region_name=settings.AWS_S3_REGION_NAME,
)


BUCKET_NAME = settings.AWS_STORAGE_BUCKET_NAME


# --------------------------------------------------
# UPLOAD IMAGE TO S3
# --------------------------------------------------

def upload_bazaar_listing_image(file, listing_id):
    """
    Upload Bazaar listing image to S3.

    S3 path:
    bazaar/listings/{listing_id}/{unique_name}.jpg
    """

    original_name = file.name

    extension = os.path.splitext(original_name)[1].lower()

    if not extension:
        extension = ".jpg"

    unique_name = f"{uuid.uuid4().hex}{extension}"

    s3_key = f"bazaar/listings/{listing_id}/{unique_name}"

    try:

        s3_client.upload_fileobj(
            file,
            BUCKET_NAME,
            s3_key,
            ExtraArgs={
                "ContentType": getattr(
                    file,
                    "content_type",
                    "image/jpeg"
                )
            }
        )

        return s3_key

    except Exception as e:

        print("S3 Upload Error:", str(e))

        raise


# --------------------------------------------------
# DELETE IMAGE FROM S3
# --------------------------------------------------

def delete_bazaar_listing_image(s3_key):

    if not s3_key:
        return

    try:

        s3_client.delete_object(
            Bucket=BUCKET_NAME,
            Key=s3_key
        )

    except Exception as e:

        print("S3 Delete Error:", str(e))


# --------------------------------------------------
# GET S3 IMAGE URL
# --------------------------------------------------

def get_bazaar_image_url(s3_key):

    if not s3_key:
        return None

    return (
        f"https://{BUCKET_NAME}.s3."
        f"{settings.AWS_S3_REGION_NAME}.amazonaws.com/"
        f"{s3_key}"
    )