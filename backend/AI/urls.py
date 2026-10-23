from django.urls import include, path


from .views import (
    PropertyPDFExtractionAPIView,

    AIChatAPIView,
    AIConversationListCreateAPIView,
    AIConversationDetailAPIView,
    AIMessageFeedbackAPIView,

    AIAdminDashboardAPIView,
    AIAdminSettingsAPIView,
    AIAdminConversationListAPIView,
    AIAdminConversationDetailAPIView,
    AIAdminMessageDetailAPIView,
    AIAdminAnalyticsAPIView,
    AIAdminUsageAPIView,
    
    )

app_name = "ai"

urlpatterns = [

    path("extract-property/", PropertyPDFExtractionAPIView.as_view(), name="extract-property"),


    # Main AI chat
    path("chat/", AIChatAPIView.as_view(), name="ai-chat"),
    # Conversations
    path("conversations/", AIConversationListCreateAPIView.as_view(), name="ai-conversation-list-create"),
    path("conversations/<uuid:conversation_id>/", AIConversationDetailAPIView.as_view(), name="ai-conversation-detail"),
    # Feedback
    path("messages/<uuid:message_id>/feedback/", AIMessageFeedbackAPIView.as_view(), name="ai-message-feedback",),

    # =============================== #
    # ADMIN ALL API's
    # =============================== #

    # Dashboard
    path("admin/dashboard/", AIAdminDashboardAPIView.as_view(), name="ai-admin-dashboard"),
    # Settings
    path("admin/settings/", AIAdminSettingsAPIView.as_view(), name="ai-admin-settings"),
    # Conversations
    path("admin/conversations/", AIAdminConversationListAPIView.as_view(), name="ai-admin-conversations"),
    path("admin/conversations/<uuid:conversation_id>/", AIAdminConversationDetailAPIView.as_view(), name="ai-admin-conversation-detail"),
    # Messages
    path("admin/messages/<uuid:message_id>/", AIAdminMessageDetailAPIView.as_view(), name="ai-admin-message-detail"),
    # Analytics
    path("admin/analytics/", AIAdminAnalyticsAPIView.as_view(), name="ai-admin-analytics"),
    # Usage
    path("admin/usage/", AIAdminUsageAPIView.as_view(), name="ai-admin-usage"),

]




