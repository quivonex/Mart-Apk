import json

from google import genai
from google.genai import types

from ..config import config
from ..exceptions import ProviderError
from .base import BaseAIProvider


class GeminiProvider(BaseAIProvider):

    def __init__(self):
        if not config.GEMINI_API_KEY:
            raise ProviderError(
                "GEMINI_API_KEY is not configured."
            )

        self.client = genai.Client(
            api_key=config.GEMINI_API_KEY
        )

        self.model = config.GEMINI_MODEL

    def extract_property_data(
        self,
        document_text: str,
        schema: dict,
        prompt: str,
    ) -> dict:

        try:
            response = self.client.models.generate_content(
                model=self.model,
                contents=document_text,
                config=types.GenerateContentConfig(
                    system_instruction=prompt,

                    response_mime_type="application/json",

                    response_schema=schema,
                ),
            )

            if not response.text:
                raise ProviderError(
                    "Gemini returned an empty response."
                )

            try:
                return json.loads(response.text)

            except json.JSONDecodeError as exc:
                raise ProviderError(
                    "Gemini returned invalid JSON."
                ) from exc

        except ProviderError:
            raise

        except Exception as exc:
            raise ProviderError(
                f"Gemini extraction failed: {exc}"
            ) from exc