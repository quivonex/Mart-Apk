import json

from AI.prompts.intent import INTENT_PROMPT


class IntentService:

    def __init__(self, llm):
        self.llm = llm

    def extract(
        self,
        message: str,
        context_state: dict | None = None,
        summary: str = "",
    ) -> dict:

        context_state = context_state or {}

        context_text = json.dumps(
            context_state,
            ensure_ascii=False
        )

        prompt = f"""
{INTENT_PROMPT}

==================================================
CURRENT CONVERSATION CONTEXT
==================================================

{context_text}

==================================================
PREVIOUS SUMMARY
==================================================

{summary or "No previous summary."}

==================================================
CURRENT USER MESSAGE
==================================================

{message}
"""

        result = self.llm.generate(
            messages=[
                {
                    "role": "user",
                    "content": prompt,
                }
            ],
            temperature=0.0,
            response_format="json",
            max_tokens=1000,
        )

        try:
            data = json.loads(result["text"])
        except json.JSONDecodeError as exc:
            raise ValueError(
                "Gemini returned invalid intent JSON."
            ) from exc

        return {
            "data": data,
            "model": result.get("model", ""),
            "prompt_tokens": result.get("prompt_tokens", 0),
            "completion_tokens": result.get(
                "completion_tokens",
                0
            ),
        }