import pymupdf

from ..exceptions import ImageExtractionError


class PDFImageExtractor:

    def extract(self, pdf_path: str) -> list[dict]:

        document = None

        try:
            document = pymupdf.open(pdf_path)

            images = []

            for page_index, page in enumerate(
                document,
                start=1
            ):

                image_list = page.get_images(
                    full=True
                )

                for image_index, image in enumerate(
                    image_list,
                    start=1
                ):

                    xref = image[0]

                    extracted = document.extract_image(
                        xref
                    )

                    if not extracted:
                        continue

                    image_bytes = extracted["image"]
                    extension = extracted["ext"]

                    images.append(
                        {
                            "page_number": page_index,
                            "image_index": image_index,
                            "extension": extension,
                            "mime_type": (
                                f"image/{extension}"
                            ),
                            "bytes": image_bytes,
                        }
                    )

            return images

        except Exception as exc:
            raise ImageExtractionError(
                f"Failed to extract images from PDF: {exc}"
            ) from exc

        finally:
            if document is not None:
                document.close()