from rest_framework import serializers

from .models import AIConversation, AIMessage, AIChatSettings


class AIChatSerializer(serializers.Serializer):
    conversation_id = serializers.UUIDField(
        required=False,
        allow_null=True,
    )

    message = serializers.CharField(
        required=True,
        trim_whitespace=True,
    )


class AIConversationSerializer(serializers.ModelSerializer):

    class Meta:
        model = AIConversation
        fields = [
            "id",
            "title",
            "active_service",
            "context_state",
            "message_count",
            "is_archived",
            "last_message_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "context_state",
            "message_count",
            "last_message_at",
            "created_at",
            "updated_at",
        ]


class AIMessageSerializer(serializers.ModelSerializer):

    class Meta:
        model = AIMessage
        fields = [
            "id",
            "role",
            "content",
            "service",
            "intent_data",
            "cards",
            "status",
            "llm_model",
            "prompt_tokens",
            "completion_tokens",
            "latency_ms",
            "feedback",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "role",
            "service",
            "intent_data",
            "cards",
            "status",
            "llm_model",
            "prompt_tokens",
            "completion_tokens",
            "latency_ms",
            "created_at",
        ]


class AIFeedbackSerializer(serializers.Serializer):

    feedback = serializers.ChoiceField(
        choices=[
            AIMessage.Feedback.LIKE,
            AIMessage.Feedback.DISLIKE,
        ]
    )


class AIConversationUpdateSerializer(serializers.Serializer):

    title = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=255,
    )

    is_archived = serializers.BooleanField(
        required=False,
    )



# ============================================================
# ADMIN SERIALIZERS
# ============================================================

class AIAdminSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIChatSettings
        fields = [
            "is_enabled",
            "history_window",
            "summary_threshold",
            "max_results_per_query",
            "max_message_length",
            "daily_message_limit",
            "mart_enabled",
            "remart_enabled",
            "realestate_enabled",
            "updated_at",
        ]
        read_only_fields = [
            "updated_at",
        ]


class AIAdminUserSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    email = serializers.CharField()


class AIAdminConversationSerializer(serializers.ModelSerializer):
    user = serializers.SerializerMethodField()

    class Meta:
        model = AIConversation
        fields = [
            "id",
            "user",
            "title",
            "active_service",
            "message_count",
            "is_archived",
            "is_deleted",
            "last_message_at",
            "created_at",
            "updated_at",
        ]

    def get_user(self, obj):
        return {
            "id": obj.user.id,
            "name": getattr(obj.user, "name", ""),
            "email": getattr(obj.user, "email", ""),
        }


class AIAdminMessageSerializer(serializers.ModelSerializer):
    conversation_id = serializers.UUIDField(
        source="conversation.id",
        read_only=True
    )

    class Meta:
        model = AIMessage
        fields = [
            "id",
            "conversation_id",
            "role",
            "content",
            "service",
            "intent_data",
            "cards",
            "ref_map",
            "status",
            "error_message",
            "llm_model",
            "prompt_tokens",
            "completion_tokens",
            "latency_ms",
            "feedback",
            "created_at",
        ]