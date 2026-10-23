import time

from django.db import transaction
from django.utils import timezone

from AI.llm.gemini import GeminiClient
from AI.models import (
    AIConversation,
    AIMessage,
    AIChatSettings,
)

from AI.prompts.system import SYSTEM_PROMPT

from .intent import IntentService
from .memory import MemoryService
from .domains import (
    ProductDomain,
    RealEstateDomain,
    ReMartDomain,
)


class ChatService:

    def __init__(self):

        self.llm = GeminiClient()

        self.intent_service = IntentService(
            self.llm
        )

        self.memory_service = MemoryService()

        self.product_domain = ProductDomain()
        self.realestate_domain = RealEstateDomain()
        self.remart_domain = ReMartDomain()

    @transaction.atomic
    def chat(
        self,
        user,
        message: str,
        conversation_id=None,
    ):

        start_time = time.monotonic()

        settings_obj = (
            AIChatSettings.get_solo()
        )

        if not settings_obj.is_enabled:
            raise ValueError(
                "AI assistant is currently disabled."
            )

        if not message.strip():
            raise ValueError(
                "Message cannot be empty."
            )

        if len(message) > settings_obj.max_message_length:
            raise ValueError(
                "Message is too long."
            )

        conversation = (
            self._get_conversation(
                user=user,
                conversation_id=conversation_id,
            )
        )

        # ---------------------------------------
        # Save user message
        # ---------------------------------------

        user_message = AIMessage.objects.create(
            conversation=conversation,
            role=AIMessage.Role.USER,
            content=message,
        )

        conversation.message_count += 1
        conversation.last_message_at = timezone.now()
        conversation.save(
            update_fields=[
                "message_count",
                "last_message_at",
                "updated_at",
            ]
        )

        # ---------------------------------------
        # Extract intent
        # ---------------------------------------

        intent_result = (
            self.intent_service.extract(
                message=message,
                context_state=(
                    conversation.context_state
                    or {}
                ),
                summary=conversation.summary,
            )
        )

        intent = intent_result["data"]

        service = intent.get(
            "service",
            "general",
        )

        intent_name = intent.get(
            "intent",
            "conversation",
        )

        filters = intent.get(
            "filters",
            {},
        )

        limit = intent.get(
            "limit"
        ) or settings_obj.max_results_per_query

        limit = min(
            int(limit),
            settings_obj.max_results_per_query,
        )

        # ---------------------------------------
        # Validate service
        # ---------------------------------------

        self._validate_service(
            service=service,
            settings_obj=settings_obj,
        )

        # ---------------------------------------
        # Update conversation context
        # ---------------------------------------

        self.memory_service.update_context(
            conversation=conversation,
            intent_data=intent,
        )

        # ---------------------------------------
        # Execute domain
        # ---------------------------------------

        domain_result = (
            self._execute_domain(
                user=user,
                service=service,
                intent=intent_name,
                filters=filters,
                limit=limit,
            )
        )

        cards = domain_result.get(
            "cards",
            [],
        )

        # ---------------------------------------
        # Build LLM history
        # ---------------------------------------

        history = (
            self.memory_service.build_history(
                conversation=conversation,
                limit=settings_obj.history_window,
            )
        )

        # Current user message was already saved,
        # therefore history already contains it.

        results_text = self._format_results(
            domain_result
        )

        llm_messages = [
            {
                "role": "system",
                "content": SYSTEM_PROMPT,
            }
        ]

        if conversation.summary:

            llm_messages.append(
                {
                    "role": "user",
                    "content": (
                        "Conversation summary:\n"
                        f"{conversation.summary}"
                    ),
                }
            )

        llm_messages.extend(history)

        llm_messages.append(
            {
                "role": "user",
                "content": (
                    "Application results:\n"
                    f"{results_text}\n\n"
                    "Respond to the user's latest request "
                    "using only the supplied application results."
                ),
            }
        )

        # ---------------------------------------
        # Generate response
        # ---------------------------------------

        llm_result = self.llm.generate(
            messages=llm_messages,
            temperature=0.3,
            max_tokens=1200,
        )

        assistant_content = llm_result["text"]

        latency_ms = int(
            (time.monotonic() - start_time) * 1000
        )

        # ---------------------------------------
        # Build reference map
        # ---------------------------------------

        ref_map = self._build_ref_map(
            cards
        )

        # ---------------------------------------
        # Save assistant message
        # ---------------------------------------

        assistant_message = AIMessage.objects.create(
            conversation=conversation,
            role=AIMessage.Role.ASSISTANT,
            content=assistant_content,
            service=service,
            intent_data=intent,
            cards=cards,
            ref_map=ref_map,
            status=AIMessage.Status.SUCCESS,
            llm_model=llm_result.get(
                "model",
                "",
            ),
            prompt_tokens=llm_result.get(
                "prompt_tokens",
                0,
            ),
            completion_tokens=llm_result.get(
                "completion_tokens",
                0,
            ),
            latency_ms=latency_ms,
        )

        conversation.message_count += 1
        conversation.last_message_at = timezone.now()

        if not conversation.title:
            conversation.title = message[:255]

        conversation.save(
            update_fields=[
                "message_count",
                "last_message_at",
                "title",
                "updated_at",
            ]
        )

        return {
            "conversation": conversation,
            "user_message": user_message,
            "assistant_message": assistant_message,
        }

    def _get_conversation(
        self,
        user,
        conversation_id=None,
    ):

        if conversation_id:

            conversation = (
                AIConversation.objects
                .filter(
                    id=conversation_id,
                    user=user,
                    is_deleted=False,
                )
                .first()
            )

            if not conversation:
                raise ValueError(
                    "Conversation not found."
                )

            return conversation

        return AIConversation.objects.create(
            user=user,
            title="",
        )

    def _validate_service(
        self,
        service,
        settings_obj,
    ):

        if service == "mart":
            if not settings_obj.mart_enabled:
                raise ValueError(
                    "QNX Mart assistant is disabled."
                )

        elif service == "remart":
            if not settings_obj.remart_enabled:
                raise ValueError(
                    "QNX ReMart assistant is disabled."
                )

        elif service == "realestate":
            if not settings_obj.realestate_enabled:
                raise ValueError(
                    "Real Estate assistant is disabled."
                )

    def _execute_domain(
        self,
        user,
        service,
        intent,
        filters,
        limit,
    ):

        if service == "mart":

            if intent == "search_products":
                return self.product_domain.search_products(
                    filters=filters,
                    limit=limit,
                )

            if intent == "cart":
                return self.product_domain.get_cart(
                    user=user
                )

            if intent == "orders":
                return self.product_domain.get_orders(
                    user=user,
                    limit=limit,
                )

            if intent == "order_details":

                return self.product_domain.get_order(
                    user=user,
                    order_id=filters.get(
                        "order_id"
                    ),
                ) or {
                    "items": []
                }

            if intent == "product_details":

                return {
                    "items": []
                }

        elif service == "realestate":

            if intent == "search_properties":
                return (
                    self.realestate_domain
                    .search_properties(
                        filters=filters,
                        limit=limit,
                    )
                )

            if intent == "property_details":

                property_data = (
                    self.realestate_domain
                    .get_property(
                        slug=filters.get("slug")
                    )
                )

                return {
                    "items": (
                        [property_data]
                        if property_data
                        else []
                    )
                }

        elif service == "remart":

            if intent == "search_listings":

                return (
                    self.remart_domain
                    .search_listings(
                        filters=filters,
                        limit=limit,
                    )
                )

        return {
            "items": [],
            "cards": [],
        }

    def _format_results(
        self,
        result,
    ):

        import json

        safe_result = {
            key: value
            for key, value in result.items()
            if key != "ref_map"
        }

        return json.dumps(
            safe_result,
            ensure_ascii=False,
            default=str,
        )

    def _build_ref_map(
        self,
        cards,
    ):

        ref_map = {}

        for card in cards:

            ref = card.get("ref")

            if not ref:
                continue

            if card.get("type") == "product":
                ref_map[ref] = {
                    "model": "product",
                    "pk": self._extract_pk(ref),
                }

            elif card.get("type") == "property":
                ref_map[ref] = {
                    "model": "property",
                    "pk": self._extract_pk(ref),
                }

            elif card.get("type") == "remart_listing":
                ref_map[ref] = {
                    "model": "bazaar_listing",
                    "pk": self._extract_pk(ref),
                }

        return ref_map

    def _extract_pk(self, ref):

        return int(
            "".join(
                character
                for character in ref
                if character.isdigit()
            )
        )