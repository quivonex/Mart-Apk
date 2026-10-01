from uuid import uuid4

from .config import config
from .documents import (
    PDFImageExtractor,
    PDFProcessor,
)
from .exceptions import ExtractionError
from .prompt import PROPERTY_EXTRACTION_PROMPT
from .schema import PROPERTY_SCHEMA
from .storage import S3Storage
from .providers import (
    GeminiProvider,
    OpenAIProvider,
)


class PropertyExtractor:

    def __init__(
        self,
        provider=None,
        storage=None,
    ):

        # =====================================================
        # AI PROVIDER
        # =====================================================

        if provider is not None:
            self.provider = provider

        elif config.AI_PROVIDER == "gemini":
            self.provider = GeminiProvider()

        elif config.AI_PROVIDER == "openai":
            self.provider = OpenAIProvider()

        else:
            raise ExtractionError(
                f"Unsupported AI provider: "
                f"{config.AI_PROVIDER}"
            )

        # =====================================================
        # DOCUMENT PROCESSORS
        # =====================================================

        self.pdf_processor = PDFProcessor()
        self.image_extractor = PDFImageExtractor()

        # =====================================================
        # STORAGE
        # =====================================================

        self.storage = (
            storage
            if storage is not None
            else S3Storage()
        )

    def extract(
        self,
        pdf_path: str,
        document_id: str | None = None,
    ) -> dict:

        if not document_id:
            document_id = uuid4().hex

        try:

            # =================================================
            # STEP 1: Extract PDF text
            # =================================================

            document_text = (
                self.pdf_processor.extract_text(
                    pdf_path
                )
            )

            # =================================================
            # STEP 2: Extract original PDF images
            # =================================================

            extracted_images = (
                self.image_extractor.extract(
                    pdf_path
                )
            )

            # =================================================
            # STEP 3: Send document text to AI
            # =================================================

            property_data = (
                self.provider.extract_property_data(
                    document_text=document_text,
                    schema=PROPERTY_SCHEMA,
                    prompt=PROPERTY_EXTRACTION_PROMPT,
                )
            )

            # =================================================
            # STEP 4: Upload original images to S3
            # =================================================

            images = []

            for image in extracted_images:

                uploaded = self.storage.save_image(
                    image_bytes=image["bytes"],
                    extension=image["extension"],
                    content_type=image["mime_type"],
                    document_id=document_id,
                )

                images.append(
                    {
                        "page_number": image[
                            "page_number"
                        ],
                        "image_index": image[
                            "image_index"
                        ],
                        "s3_key": uploaded["key"],
                        "url": uploaded["url"],
                    }
                )

            # =================================================
            # STEP 5: Final response
            # =================================================

            return {
                "success": True,
                "document_id": document_id,
                "data": property_data,
                "images": images,
            }

        except Exception as exc:

            if isinstance(
                exc,
                ExtractionError,
            ):
                raise

            raise ExtractionError(
                f"Property extraction failed: {exc}"
            ) from exc