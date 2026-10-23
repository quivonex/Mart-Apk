from pathlib import Path
from tempfile import NamedTemporaryFile

from django.db.models import Count, Sum, Avg
from django.db.models.functions import TruncDate
from django.db.models import Count
from django.utils import timezone

from rest_framework import status
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from .ai_engine import PropertyExtractor
from .ai_engine.exceptions import ExtractionError

from .models import (
    AIConversation,
    AIMessage,
    AIChatSettings,
)

from .serializers import (
    AIChatSerializer,
    AIConversationSerializer,
    AIMessageSerializer,
    AIFeedbackSerializer,
    AIConversationUpdateSerializer,

    AIAdminSettingsSerializer,
    AIAdminConversationSerializer,
    AIAdminMessageSerializer,
)

from .services.chat import ChatService
from .throttles import AIChatThrottle









class PropertyPDFExtractionAPIView(APIView):
    """
    Extract real-estate property information and images
    from an uploaded PDF.
    """

    parser_classes = [
        MultiPartParser,
        FormParser,
    ]

    def post(self, request):
        pdf_file = request.FILES.get("file")

        # -----------------------------------------------------
        # Validate file
        # -----------------------------------------------------

        if not pdf_file:
            return Response(
                {
                    "success": False,
                    "message": "PDF file is required.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # -----------------------------------------------------
        # Validate extension
        # -----------------------------------------------------

        extension = Path(
            pdf_file.name
        ).suffix.lower()

        if extension != ".pdf":
            return Response(
                {
                    "success": False,
                    "message": "Only PDF files are allowed.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        temporary_file_path = None

        try:
            # -------------------------------------------------
            # Save uploaded PDF temporarily
            # -------------------------------------------------

            with NamedTemporaryFile(
                suffix=".pdf",
                delete=False,
            ) as temporary_file:
                for chunk in pdf_file.chunks():
                    temporary_file.write(chunk)
                temporary_file_path = (
                    temporary_file.name
                )

            # -------------------------------------------------
            # Run AI extraction
            # -------------------------------------------------

            extractor = PropertyExtractor()
            result = extractor.extract(
                pdf_path=temporary_file_path,
            )

            # -------------------------------------------------
            # Return response
            # -------------------------------------------------

            return Response(
                result,
                status=status.HTTP_200_OK,
            )

        except ExtractionError as exc:
            return Response(
                {
                    "success": False,
                    "message": str(exc),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        except Exception as exc:
            return Response(
                {
                    "success": False,
                    "message": (
                        "An unexpected error occurred."
                    ),
                    "error": str(exc),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        finally:
            # -------------------------------------------------
            # Delete temporary PDF
            # -------------------------------------------------

            if temporary_file_path:
                temporary_path = Path(
                    temporary_file_path
                )
                if temporary_path.exists():
                    temporary_path.unlink()


class AIChatAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    throttle_classes = [AIChatThrottle]

    def post(self, request):
        serializer = AIChatSerializer(
            data=request.data
        )
        serializer.is_valid(
            raise_exception=True
        )
        message = serializer.validated_data[
            "message"
        ]
        conversation_id = serializer.validated_data.get(
            "conversation_id"
        )
        settings_obj = AIChatSettings.get_solo()

        if not settings_obj.is_enabled:
            return Response(
                {
                    "success": False,
                    "message": (
                        "AI assistant is currently disabled."
                    ),
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # -----------------------------------------
        # Daily message limit
        # -----------------------------------------

        today = timezone.localdate()
        daily_count = AIMessage.objects.filter(
            conversation__user=request.user,
            role=AIMessage.Role.USER,
            created_at__date=today,
        ).count()

        if daily_count >= settings_obj.daily_message_limit:
            return Response(
                {
                    "success": False,
                    "message": (
                        "You have reached today's AI "
                        "message limit."
                    ),
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        # -----------------------------------------
        # Chat service
        # -----------------------------------------

        try:
            result = ChatService().chat(
                user=request.user,
                message=message,
                conversation_id=conversation_id,
            )
        except ValueError as exc:
            return Response(
                {
                    "success": False,
                    "message": str(exc),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception as exc:
            return Response(
                {
                    "success": False,
                    "message": (
                        "Unable to process your request "
                        "right now."
                    ),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        conversation = result["conversation"]
        user_message = result["user_message"]
        assistant_message = result["assistant_message"]

        return Response(
            {
                "success": True,
                "conversation": {
                    "id": str(conversation.id),
                    "title": conversation.title,
                    "active_service": (
                        conversation.active_service
                    ),
                },
                "user_message": {
                    "id": str(user_message.id),
                    "content": user_message.content,
                },
                "assistant_message": {
                    "id": str(assistant_message.id),
                    "content": (
                        assistant_message.content
                    ),
                    "service": (
                        assistant_message.service
                    ),
                    "cards": (
                        assistant_message.cards
                    ),
                    "created_at": (
                        assistant_message.created_at
                    ),
                },
            },
            status=status.HTTP_200_OK,
        )


class AIConversationListCreateAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        conversations = (
            AIConversation.objects
            .filter(
                user=request.user,
                is_deleted=False,
            )
            .order_by(
                "-last_message_at",
                "-created_at",
            )
        )
        serializer = AIConversationSerializer(
            conversations,
            many=True,
        )
        return Response(
            {
                "success": True,
                "count": conversations.count(),
                "results": serializer.data,
            }
        )

    def post(self, request):
        conversation = (
            AIConversation.objects.create(
                user=request.user,
                title=request.data.get(
                    "title",
                    "",
                ),
            )
        )
        serializer = AIConversationSerializer(
            conversation
        )
        return Response(
            {
                "success": True,
                "conversation": serializer.data,
            },
            status=status.HTTP_201_CREATED,
        )


class AIConversationDetailAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get_object(
        self,
        request,
        conversation_id,
    ):
        return (
            AIConversation.objects
            .filter(
                id=conversation_id,
                user=request.user,
                is_deleted=False,
            )
            .first()
        )

    def get(
        self,
        request,
        conversation_id,
    ):
        conversation = self.get_object(
            request,
            conversation_id,
        )
        if not conversation:
            return Response(
                {
                    "success": False,
                    "message": "Conversation not found.",
                },
                status=status.HTTP_404_NOT_FOUND,
            )
        messages = (
            conversation.messages
            .order_by("created_at")
        )
        return Response(
            {
                "success": True,
                "conversation": {
                    "id": str(conversation.id),
                    "title": conversation.title,
                    "active_service": (
                        conversation.active_service
                    ),
                    "context_state": (
                        conversation.context_state
                    ),
                    "message_count": (
                        conversation.message_count
                    ),
                    "is_archived": (
                        conversation.is_archived
                    ),
                    "created_at": (
                        conversation.created_at
                    ),
                    "updated_at": (
                        conversation.updated_at
                    ),
                },
                "messages": AIMessageSerializer(
                    messages,
                    many=True,
                ).data,
            }
        )

    def patch(
        self,
        request,
        conversation_id,
    ):
        conversation = self.get_object(
            request,
            conversation_id,
        )
        if not conversation:
            return Response(
                {
                    "success": False,
                    "message": "Conversation not found.",
                },
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = AIConversationUpdateSerializer(
            data=request.data
        )
        serializer.is_valid(
            raise_exception=True
        )
        validated = serializer.validated_data
        if "title" in validated:
            conversation.title = validated["title"]
        if "is_archived" in validated:
            conversation.is_archived = validated[
                "is_archived"
            ]
        conversation.save()
        return Response(
            {
                "success": True,
                "conversation": AIConversationSerializer(
                    conversation
                ).data,
            }
        )

    def delete(
        self,
        request,
        conversation_id,
    ):
        conversation = self.get_object(
            request,
            conversation_id,
        )
        if not conversation:
            return Response(
                {
                    "success": False,
                    "message": "Conversation not found.",
                },
                status=status.HTTP_404_NOT_FOUND,
            )
        conversation.is_deleted = True
        conversation.save(
            update_fields=[
                "is_deleted",
                "updated_at",
            ]
        )
        return Response(
            {
                "success": True,
                "message": "Conversation deleted.",
            },
            status=status.HTTP_200_OK,
        )


class AIMessageFeedbackAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(
        self,
        request,
        message_id,
    ):
        serializer = AIFeedbackSerializer(
            data=request.data
        )
        serializer.is_valid(
            raise_exception=True
        )
        feedback = serializer.validated_data[
            "feedback"
        ]
        message = (
            AIMessage.objects
            .filter(
                id=message_id,
                conversation__user=request.user,
                role=AIMessage.Role.ASSISTANT,
                conversation__is_deleted=False,
            )
            .first()
        )
        if not message:
            return Response(
                {
                    "success": False,
                    "message": "Message not found.",
                },
                status=status.HTTP_404_NOT_FOUND,
            )
        message.feedback = feedback
        message.save(
            update_fields=[
                "feedback",
            ]
        )
        return Response(
            {
                "success": True,
                "message": "Feedback saved.",
                "feedback": feedback,
            }
        )





# ------------------------------------------------------ #
# ----------------------ADMIN API'S--------------------- #
# ------------------------------------------------------ #



from django.db.models import Count, Sum, Avg
from django.db.models.functions import TruncDate
from django.utils import timezone

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.pagination import PageNumberPagination

from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import (
    AIConversation,
    AIMessage,
    AIChatSettings,
)

from .serializers import (
    AIAdminSettingsSerializer,
    AIAdminConversationSerializer,
    AIAdminMessageSerializer,
)

# ============================================================
# COMMON
# ============================================================

class AdminPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100

# ============================================================
# 1. DASHBOARD
# ============================================================

class AIAdminDashboardAPIView(APIView):
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def get(self, request):
        today = timezone.localdate()
        total_conversations = AIConversation.objects.count()
        total_messages = AIMessage.objects.count()
        total_users = (
            AIConversation.objects
            .values("user")
            .distinct()
            .count()
        )
        today_messages = AIMessage.objects.filter(
            created_at__date=today
        ).count()
        today_conversations = AIConversation.objects.filter(
            created_at__date=today
        ).count()
        successful_messages = AIMessage.objects.filter(
            status=AIMessage.Status.SUCCESS
        ).count()
        failed_messages = AIMessage.objects.filter(
            status=AIMessage.Status.FAILED
        ).count()
        likes = AIMessage.objects.filter(
            feedback=AIMessage.Feedback.LIKE
        ).count()
        dislikes = AIMessage.objects.filter(
            feedback=AIMessage.Feedback.DISLIKE
        ).count()
        service_usage = (
            AIMessage.objects
            .values("service")
            .annotate(count=Count("id"))
            .order_by("-count")
        )

        return Response({
            "total_conversations": total_conversations,
            "total_messages": total_messages,
            "total_users": total_users,
            "today": {
                "messages": today_messages,
                "conversations": today_conversations,
            },
            "messages": {
                "successful": successful_messages,
                "failed": failed_messages,
            },
            "feedback": {
                "likes": likes,
                "dislikes": dislikes,
            },
            "service_usage": service_usage,
        })

# ============================================================
# 2 & 3. SETTINGS
# ============================================================

class AIAdminSettingsAPIView(APIView):
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def get(self, request):
        settings = AIChatSettings.get_solo()
        serializer = AIAdminSettingsSerializer(settings)
        return Response(serializer.data)

    def patch(self, request):
        settings = AIChatSettings.get_solo()
        serializer = AIAdminSettingsSerializer(
            settings,
            data=request.data,
            partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

# ============================================================
# 4. ALL CONVERSATIONS
# ============================================================

class AIAdminConversationListAPIView(APIView):
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def get(self, request):
        queryset = (
            AIConversation.objects
            .select_related("user")
            .all()
            .order_by("-last_message_at", "-created_at")
        )

        # Search
        search = request.query_params.get("search")
        if search:
            queryset = queryset.filter(
                title__icontains=search
            )

        # Service filter
        service = request.query_params.get("service")
        if service:
            queryset = queryset.filter(
                active_service=service
            )

        # Archived filter
        is_archived = request.query_params.get("is_archived")
        if is_archived is not None:
            queryset = queryset.filter(
                is_archived=is_archived.lower() == "true"
            )

        # Deleted filter
        is_deleted = request.query_params.get("is_deleted")
        if is_deleted is not None:
            queryset = queryset.filter(
                is_deleted=is_deleted.lower() == "true"
            )

        # User filter
        user_id = request.query_params.get("user_id")
        if user_id:
            queryset = queryset.filter(
                user_id=user_id
            )

        paginator = AdminPagination()
        page = paginator.paginate_queryset(
            queryset,
            request
        )
        serializer = AIAdminConversationSerializer(
            page,
            many=True
        )
        return paginator.get_paginated_response(
            serializer.data
        )

# ============================================================
# 5. CONVERSATION DETAILS
# ============================================================

class AIAdminConversationDetailAPIView(APIView):
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def get(self, request, conversation_id):
        try:
            conversation = (
                AIConversation.objects
                .select_related("user")
                .get(id=conversation_id)
            )
        except AIConversation.DoesNotExist:
            return Response(
                {
                    "detail": "Conversation not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        conversation_data = AIAdminConversationSerializer(
            conversation
        ).data
        messages = (
            conversation.messages
            .all()
            .order_by("created_at")
        )
        message_data = AIAdminMessageSerializer(
            messages,
            many=True
        ).data

        return Response({
            "conversation": conversation_data,
            "messages": message_data
        })

# ============================================================
# 6. MESSAGE DETAILS
# ============================================================

class AIAdminMessageDetailAPIView(APIView):
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def get(self, request, message_id):
        try:
            message = (
                AIMessage.objects
                .select_related("conversation", "conversation__user")
                .get(id=message_id)
            )
        except AIMessage.DoesNotExist:
            return Response(
                {
                    "detail": "Message not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = AIAdminMessageSerializer(message)
        return Response(serializer.data)

# ============================================================
# 7. ANALYTICS
# ============================================================

class AIAdminAnalyticsAPIView(APIView):
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def get(self, request):
        today = timezone.localdate()
        days = request.query_params.get("days", 7)

        try:
            days = int(days)
        except ValueError:
            days = 7

        if days not in [7, 30, 90]:
            days = 7

        start_date = today - timezone.timedelta(
            days=days - 1
        )
        messages = AIMessage.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=today
        )
        daily_messages = (
            messages
            .annotate(date=TruncDate("created_at"))
            .values("date")
            .annotate(count=Count("id"))
            .order_by("date")
        )
        service_usage = (
            messages
            .values("service")
            .annotate(count=Count("id"))
            .order_by("-count")
        )
        feedback = {
            "likes": messages.filter(
                feedback=AIMessage.Feedback.LIKE
            ).count(),
            "dislikes": messages.filter(
                feedback=AIMessage.Feedback.DISLIKE
            ).count(),
        }

        return Response({
            "period": {
                "days": days,
                "from": start_date,
                "to": today,
            },
            "daily_messages": daily_messages,
            "service_usage": service_usage,
            "feedback": feedback,
        })

# ============================================================
# 8. USAGE
# ============================================================

class AIAdminUsageAPIView(APIView):
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def get(self, request):
        messages = AIMessage.objects.filter(
            role=AIMessage.Role.ASSISTANT,
            status=AIMessage.Status.SUCCESS
        )
        total_requests = messages.count()
        usage = messages.aggregate(
            prompt_tokens=Sum("prompt_tokens"),
            completion_tokens=Sum("completion_tokens"),
            average_latency=Avg("latency_ms"),
        )
        prompt_tokens = usage["prompt_tokens"] or 0
        completion_tokens = usage["completion_tokens"] or 0
        total_tokens = (
            prompt_tokens +
            completion_tokens
        )
        models = (
            messages
            .values("llm_model")
            .annotate(
                requests=Count("id"),
                prompt_tokens=Sum("prompt_tokens"),
                completion_tokens=Sum("completion_tokens"),
            )
            .order_by("-requests")
        )

        return Response({
            "total_requests": total_requests,
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": total_tokens,
            "average_latency_ms": round(
                usage["average_latency"] or 0,
                2
            ),
            "models": models,
        })