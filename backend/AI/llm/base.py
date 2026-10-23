from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional


class BaseLLM(ABC):

    @abstractmethod
    def generate(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.2,
        max_tokens: Optional[int] = None,
        response_format: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Generate a response from the LLM.

        Expected return:

        {
            "text": "...",
            "model": "...",
            "prompt_tokens": 0,
            "completion_tokens": 0,
        }
        """
        raise NotImplementedError