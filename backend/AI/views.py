from pathlib import Path
from tempfile import NamedTemporaryFile

from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .ai_engine import PropertyExtractor
from .ai_engine.exceptions import ExtractionError


class PropertyPDFExtractionAPIView(APIView):
    """
    Extract real-estate property information and images
    from an uploaded PDF.
    """

    parser_classes = [
        MultiPartParser,
        FormParser,
    ]

    def post(self, request):

        pdf_file = request.FILES.get("file")

        # -----------------------------------------------------
        # Validate file
        # -----------------------------------------------------

        if not pdf_file:
            return Response(
                {
                    "success": False,
                    "message": "PDF file is required.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # -----------------------------------------------------
        # Validate extension
        # -----------------------------------------------------

        extension = Path(
            pdf_file.name
        ).suffix.lower()

        if extension != ".pdf":
            return Response(
                {
                    "success": False,
                    "message": "Only PDF files are allowed.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        temporary_file_path = None

        try:

            # -------------------------------------------------
            # Save uploaded PDF temporarily
            # -------------------------------------------------

            with NamedTemporaryFile(
                suffix=".pdf",
                delete=False,
            ) as temporary_file:

                for chunk in pdf_file.chunks():
                    temporary_file.write(chunk)

                temporary_file_path = (
                    temporary_file.name
                )

            # -------------------------------------------------
            # Run AI extraction
            # -------------------------------------------------

            extractor = PropertyExtractor()

            result = extractor.extract(
                pdf_path=temporary_file_path,
            )

            # -------------------------------------------------
            # Return response
            # -------------------------------------------------

            return Response(
                result,
                status=status.HTTP_200_OK,
            )

        except ExtractionError as exc:

            return Response(
                {
                    "success": False,
                    "message": str(exc),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        except Exception as exc:

            return Response(
                {
                    "success": False,
                    "message": (
                        "An unexpected error occurred."
                    ),
                    "error": str(exc),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        finally:

            # -------------------------------------------------
            # Delete temporary PDF
            # -------------------------------------------------

            if temporary_file_path:

                temporary_path = Path(
                    temporary_file_path
                )

                if temporary_path.exists():
                    temporary_path.unlink()