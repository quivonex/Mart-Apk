import pymupdf

from ..exceptions import DocumentProcessingError


class PDFProcessor:

    def extract_text(self, pdf_path: str) -> str:

        document = None

        try:
            document = pymupdf.open(pdf_path)

            pages = []

            for page_number, page in enumerate(
                document,
                start=1
            ):
                text = page.get_text("text")

                pages.append(
                    f"--- PAGE {page_number} ---\n"
                    f"{text.strip()}"
                )

            return "\n\n".join(pages)

        except Exception as exc:
            raise DocumentProcessingError(
                f"Failed to process PDF: {exc}"
            ) from exc

        finally:
            if document is not None:
                document.close()