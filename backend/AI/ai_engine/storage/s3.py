import boto3
from botocore.exceptions import BotoCoreError, ClientError
from uuid import uuid4

from ..config import config
from ..exceptions import StorageError


class S3Storage:

    def __init__(self):
        if not config.AWS_S3_BUCKET:
            raise StorageError(
                "AWS_S3_BUCKET is not configured."
            )

        self.bucket = config.AWS_S3_BUCKET

        self.client = boto3.client(
            "s3",
            aws_access_key_id=config.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY,
            region_name=config.AWS_REGION,
        )

    def save_image(
        self,
        image_bytes: bytes,
        extension: str,
        content_type: str,
        document_id: str,
    ) -> dict:

        filename = f"{uuid4().hex}.{extension}"

        key = (
            f"{config.AWS_S3_PREFIX_PDF_ASSISTANT}/"
            f"documents/{document_id}/"
            f"images/{filename}"
        )

        try:
            self.client.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=image_bytes,
                ContentType=content_type,
            )

            # Permanent S3 object URL.
            #
            # This URL does NOT expire like a presigned URL.
            # The object must be publicly accessible through
            # the bucket/object policy for this URL to work.
            url = (
                f"https://{self.bucket}.s3."
                f"{config.AWS_REGION}.amazonaws.com/"
                f"{key}"
            )

            return {
                "key": key,
                "bucket": self.bucket,
                "region": config.AWS_REGION,
                "url": url,
            }

        except (
            BotoCoreError,
            ClientError,
        ) as exc:

            raise StorageError(
                f"Failed to upload image to S3: {exc}"
            ) from exc