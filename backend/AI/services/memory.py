from AI.models import AIMessage


class MemoryService:

    def get_recent_messages(
        self,
        conversation,
        limit: int = 6,
    ):

        return list(
            conversation.messages
            .order_by("-created_at")[:limit]
        )[::-1]

    def build_history(
        self,
        conversation,
        limit: int = 6,
    ):

        messages = self.get_recent_messages(
            conversation=conversation,
            limit=limit,
        )

        history = []

        for message in messages:

            role = (
                "assistant"
                if message.role == AIMessage.Role.ASSISTANT
                else "user"
            )

            history.append(
                {
                    "role": role,
                    "content": message.content,
                }
            )

        return history

    def update_context(
        self,
        conversation,
        intent_data: dict,
    ):

        service = intent_data.get("service")

        filters = intent_data.get(
            "filters",
            {}
        )

        context = conversation.context_state or {}

        if service:
            conversation.active_service = service

        if filters:
            context.update(
                {
                    key: value
                    for key, value in filters.items()
                    if value is not None
                }
            )

        conversation.context_state = context

        conversation.save(
            update_fields=[
                "active_service",
                "context_state",
                "updated_at",
            ]
        )

    def should_summarize(
        self,
        conversation,
        threshold: int,
    ):

        if conversation.message_count < threshold:
            return False

        return True