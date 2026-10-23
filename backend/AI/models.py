import uuid

from django.conf import settings
from django.db import models


class ServiceType(models.TextChoices):
    GENERAL = "general", "General"
    MART = "mart", "QNX Mart"
    REMART = "remart", "QNX ReMart"
    REALESTATE = "realestate", "Real Estate"


class AIConversation(models.Model):
    """
    One chat thread owned by one authenticated user.
    Holds the rolling summary so we never send full history to the LLM.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="ai_conversations")
    title = models.CharField(max_length=255, blank=True)

    # Last service the user was talking about (helps follow-ups like "show cheaper ones")
    active_service = models.CharField(max_length=20, choices=ServiceType.choices, default=ServiceType.GENERAL)

    # Last extracted filters, e.g. {"city": "Pune", "bhk": 2, "max_budget": 8000000}
    context_state = models.JSONField(default=dict, blank=True)

    # ---- Memory ----
    summary = models.TextField(blank=True)
    last_summarized_message = models.ForeignKey(
        "AIMessage", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    message_count = models.PositiveIntegerField(default=0)

    # ---- State ----
    is_archived = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)  # soft delete, keeps data for analytics

    last_message_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "ai_conversations"
        ordering = ["-last_message_at", "-created_at"]
        indexes = [
            models.Index(fields=["user", "is_deleted", "-last_message_at"]),
        ]

    def __str__(self):
        return f"{self.user} - {self.title or 'New chat'}"


class AIMessage(models.Model):
    """
    A single message in a conversation (user or assistant).
    `cards` go to the frontend; `ref_map` stays on the server and is never
    sent to the LLM or exposed through the API.
    """

    class Role(models.TextChoices):
        USER = "user", "User"
        ASSISTANT = "assistant", "Assistant"

    class Status(models.TextChoices):
        SUCCESS = "success", "Success"
        FAILED = "failed", "Failed"

    class Feedback(models.IntegerChoices):
        DISLIKE = -1, "Dislike"
        LIKE = 1, "Like"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(AIConversation, on_delete=models.CASCADE, related_name="messages")
    role = models.CharField(max_length=10, choices=Role.choices)
    content = models.TextField()

    # ---- Intent (filled on user messages) ----
    service = models.CharField(max_length=20, choices=ServiceType.choices, default=ServiceType.GENERAL)
    intent_data = models.JSONField(default=dict, blank=True)

    # ---- Results (filled on assistant messages) ----
    # Frontend cards: [{"ref": "P1", "type": "product", "slug": "...", "title": "...", "price": "...", "image": "..."}]
    cards = models.JSONField(default=list, blank=True)
    # Server only: {"P1": {"model": "product", "pk": 12}}
    ref_map = models.JSONField(default=dict, blank=True)

    # ---- Observability ----
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.SUCCESS)
    error_message = models.TextField(blank=True)
    llm_model = models.CharField(max_length=100, blank=True)
    prompt_tokens = models.PositiveIntegerField(default=0)
    completion_tokens = models.PositiveIntegerField(default=0)
    latency_ms = models.PositiveIntegerField(default=0)

    feedback = models.SmallIntegerField(choices=Feedback.choices, null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "ai_messages"
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["conversation", "created_at"]),
        ]

    def __str__(self):
        return f"{self.role}: {self.content[:40]}"


class AIChatSettings(models.Model):
    """
    Single-row settings editable from admin (same pattern as BazaarSettings),
    so memory/limits can be tuned without a redeploy.
    """

    is_enabled = models.BooleanField(default=True)

    # Memory tuning
    history_window = models.PositiveIntegerField(default=6)        # recent messages sent raw to LLM
    summary_threshold = models.PositiveIntegerField(default=10)    # unsummarized msgs before re-summarizing

    # Limits
    max_results_per_query = models.PositiveIntegerField(default=5)
    max_message_length = models.PositiveIntegerField(default=1000)
    daily_message_limit = models.PositiveIntegerField(default=100)  # per user

    # Which services the bot may answer about
    mart_enabled = models.BooleanField(default=True)
    remart_enabled = models.BooleanField(default=True)
    realestate_enabled = models.BooleanField(default=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "ai_chat_settings"
        verbose_name = "AI Chat Settings"
        verbose_name_plural = "AI Chat Settings"

    def __str__(self):
        return "AI Chat Settings"

    @classmethod
    def get_solo(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj
