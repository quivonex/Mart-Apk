import re
import unicodedata

from django.utils.html import strip_tags
from rest_framework.exceptions import ValidationError

from olx.models import BazaarCommunicationSettings

class BazaarContactInfoFilterService:
    """
    Server-side contact information detection for chat/enquiry messages.

    This is a practical first layer, not a guarantee that every possible
    obfuscated contact detail can be detected.
    """

    EMAIL_PATTERN = re.compile(
        r"\b[A-Z0-9._%+-]+\s*@\s*[A-Z0-9.-]+\s*\.\s*[A-Z]{2,}\b",
        re.IGNORECASE,
    )
    URL_PATTERN = re.compile(
        r"(?i)\b(?:https?://|www\.)\S+"
        r"|\b[a-z0-9-]+\.(?:com|in|net|org|co|io|me|info|"
        r"app|site|xyz|gg|link|ly)\b(?:/\S*)?"
    )
    SOCIAL_HANDLE_PATTERN = re.compile(
        r"(?<![\w@])@[A-Za-z0-9._]{2,30}\b"
    )
    PHONE_CANDIDATE_PATTERN = re.compile(
        r"(?<!\w)(?:\+?\d[\d\s().\-]{7,}\d)(?!\w)"
    )
    SOCIAL_PLATFORM_PATTERN = re.compile(
        r"\b(?:"
        r"whatsapp|telegram|instagram|facebook|snapchat|"
        r"discord|signal|skype|linkedin|wechat|"
        r"messenger|tiktok|twitter|x\.com"
        r")\b",
        re.IGNORECASE,
    )

    @classmethod
    def get_settings(cls):
        return (
            BazaarCommunicationSettings.objects
            .filter(is_active=True)
            .order_by("-updated_at", "-id")
            .first()
        )

    @staticmethod
    def normalize_text(text):
        text = unicodedata.normalize("NFKC", text or "")
        text = strip_tags(text)
        return text.strip()

    @classmethod
    def _contains_phone_number(cls, text):
        """
        Try international/Indian number validation with phonenumbers.
        Fall back to a conservative Indian mobile-number pattern.
        """
        try:
            import phonenumbers

            for match in cls.PHONE_CANDIDATE_PATTERN.finditer(text):
                candidate = match.group(0).strip()

                try:
                    number = phonenumbers.parse(
                        candidate,
                        None if candidate.startswith("+") else "IN",
                    )
                    if phonenumbers.is_possible_number(number):
                        if phonenumbers.is_valid_number(number):
                            return True
                except phonenumbers.NumberParseException:
                    continue

            return False

        except ImportError:
            # Basic fallback for common Indian mobile numbers.
            compact = re.sub(r"\D", "", text)
            return bool(
                re.search(r"(?<!\d)[6-9]\d{9}(?!\d)", compact)
            )

    @classmethod
    def detect(cls, text, settings_obj=None):
        """
        Return detected categories. Does not raise an exception.
        """
        normalized = cls.normalize_text(text)
        if not normalized:
            return []

        settings_obj = settings_obj or cls.get_settings()
        if settings_obj is None or not settings_obj.block_contact_info:
            return []

        detected = []

        if (
            settings_obj.block_emails
            and cls.EMAIL_PATTERN.search(normalized)
        ):
            detected.append("email")

        if (
            settings_obj.block_phone_numbers
            and cls._contains_phone_number(normalized)
        ):
            detected.append("phone_number")

        if (
            settings_obj.block_external_links
            and cls.URL_PATTERN.search(normalized)
        ):
            detected.append("external_link")

        if settings_obj.block_social_handles:
            if cls.SOCIAL_HANDLE_PATTERN.search(normalized):
                detected.append("social_handle")
            if cls.SOCIAL_PLATFORM_PATTERN.search(normalized):
                detected.append("social_platform")

        return detected

    @classmethod
    def validate_message(cls, text, settings_obj=None):
        """
        Reject prohibited contact information before storing the message.
        Returns normalized text if accepted.
        """
        normalized = cls.normalize_text(text)
        if not normalized:
            raise ValidationError({
                "message": "Message cannot be empty."
            })

        detected = cls.detect(
            normalized,
            settings_obj=settings_obj,
        )
        if detected:
            raise ValidationError({
                "message": (
                    "Your message contains contact information that "
                    "is not allowed. Remove the prohibited details "
                    "and try again."
                ),
                "detected_categories": detected,
            })

        return normalized