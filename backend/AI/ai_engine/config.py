import os
from pathlib import Path

from dotenv import load_dotenv


# =========================================================
# PROJECT ROOT
# =========================================================

BASE_DIR = Path(__file__).resolve().parents[2]

ENV_FILE = BASE_DIR / ".env"


# =========================================================
# LOAD ENVIRONMENT VARIABLES
# =========================================================

load_dotenv(
    dotenv_path=ENV_FILE
)


class AIConfig:
    """
    Framework-independent configuration.
    """

    # -----------------------------------------------------
    # AI Provider
    # -----------------------------------------------------

    AI_PROVIDER = os.getenv(
        "AI_PROVIDER",
        "gemini",
    )

    # -----------------------------------------------------
    # Gemini
    # -----------------------------------------------------

    GEMINI_API_KEY = os.getenv(
        "GEMINI_API_KEY"
    )

    GEMINI_MODEL = os.getenv(
        "GEMINI_MODEL",
        "gemini-3-flash-preview",
    )

    # -----------------------------------------------------
    # OpenAI
    # -----------------------------------------------------

    OPENAI_API_KEY = os.getenv(
        "OPENAI_API_KEY"
    )

    OPENAI_MODEL = os.getenv(
        "OPENAI_MODEL",
        "gpt-5",
    )

    # -----------------------------------------------------
    # AWS S3
    # -----------------------------------------------------

    AWS_ACCESS_KEY_ID = os.getenv(
        "AWS_ACCESS_KEY_ID"
    )

    AWS_SECRET_ACCESS_KEY = os.getenv(
        "AWS_SECRET_ACCESS_KEY"
    )

    AWS_REGION = os.getenv(
        "AWS_REGION",
        "ap-south-1",
    )

    AWS_S3_BUCKET = os.getenv(
        "AWS_S3_BUCKET"
    )

    AWS_S3_PREFIX_PDF_ASSISTANT = os.getenv(
        "AWS_S3_PREFIX_PDF_ASSISTANT",
        "pdf-assistant",
    )


config = AIConfig()