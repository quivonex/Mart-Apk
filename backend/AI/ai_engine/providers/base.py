from abc import ABC, abstractmethod


class BaseAIProvider(ABC):

    @abstractmethod
    def extract_property_data(
        self,
        document_text: str,
        schema: dict,
        prompt: str,
    ) -> dict:
        """
        Extract structured property data from document text.
        """
        raise NotImplementedError