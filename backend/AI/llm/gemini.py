import os
from typing import Any, Dict, List, Optional

from google import genai
from google.genai import types

from .base import BaseLLM


class GeminiClient(BaseLLM):

    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        self.model = os.getenv(
            "GEMINI_MODEL",
            "gemini-3-flash-preview"
        )

        if not self.api_key:
            raise ValueError(
                "GEMINI_API_KEY is not configured in environment variables."
            )

        self.client = genai.Client(
            api_key=self.api_key
        )

    def generate(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.2,
        max_tokens: Optional[int] = None,
        response_format: Optional[str] = None,
    ) -> Dict[str, Any]:

        system_instruction = None
        contents = []

        for message in messages:

            role = message.get("role", "user")
            content = message.get("content", "")

            if role == "system":
                system_instruction = content
                continue

            if role == "assistant":
                contents.append(
                    types.Content(
                        role="model",
                        parts=[
                            types.Part.from_text(text=content)
                        ],
                    )
                )

            else:
                contents.append(
                    types.Content(
                        role="user",
                        parts=[
                            types.Part.from_text(text=content)
                        ],
                    )
                )

        config_kwargs = {
            "temperature": temperature,
        }

        if system_instruction:
            config_kwargs["system_instruction"] = system_instruction

        if max_tokens:
            config_kwargs["max_output_tokens"] = max_tokens

        if response_format == "json":
            config_kwargs["response_mime_type"] = "application/json"

        response = self.client.models.generate_content(
            model=self.model,
            contents=contents,
            config=types.GenerateContentConfig(
                **config_kwargs
            ),
        )

        usage = getattr(response, "usage_metadata", None)

        prompt_tokens = 0
        completion_tokens = 0

        if usage:
            prompt_tokens = getattr(
                usage,
                "prompt_token_count",
                0
            ) or 0

            completion_tokens = getattr(
                usage,
                "candidates_token_count",
                0
            ) or 0

        return {
            "text": response.text or "",
            "model": self.model,
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
        }