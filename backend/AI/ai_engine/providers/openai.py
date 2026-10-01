from ..exceptions import ProviderError
from .base import BaseAIProvider


class OpenAIProvider(BaseAIProvider):

    def __init__(self):
        raise ProviderError(
            "OpenAI provider is not implemented yet."
        )

    def extract_property_data(
        self,
        document_text: str,
        schema: dict,
        prompt: str,
    ) -> dict:

        raise ProviderError(
            "OpenAI provider is not implemented yet."
        )