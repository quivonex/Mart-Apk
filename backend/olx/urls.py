from django.urls import path

from .views import (
    BazaarAttributeCreateAPIView,
    BazaarAttributeListAPIView,
    BazaarCategoryListAPIView,
    BazaarEnquiryCreateAPIView,
    BazaarEnquiryListAPIView,
    BazaarListingCreateAPIView,
    BazaarListingListAPIView,
    BazaarListingDetailAPIView,
    BazaarListingUpdateAPIView,
    BazaarPlanCreateAPIView,
    BazaarPlanPricingListAPIView,
    BazaarPricingCreateAPIView,
    BazaarSettingsCreateAPIView,
    BazaarSettingsListAPIView,
    BazaarSettingsUpdateAPIView,
    BazaarSubCategoryCreateAPIView,
    BazaarSubCategoryDeleteAPIView,
    BazaarSubCategoryListAPIView,
    MyBazaarListingAPIView,
    BazaarPlanListAPIView,
    BazaarCreatePaymentAPIView,
    BazaarVerifyPaymentAPIView,
    BazaarCategoryCreateAPIView,

    BazaarCommunicationPlanCreateAPIView,
    BazaarCommunicationPlanListAPIView,
    BazaarCommunicationPlanUpdateAPIView,
    BazaarCommunicationPlanDeleteAPIView,
    BazaarCommunicationSettingsDetailAPIView,
    BazaarCommunicationSettingsUpdateAPIView,
    BazaarCommunicationMySubscriptionsAPIView,
    BazaarCommunicationSubscriptionDetailAPIView,
    BazaarCommunicationChatUsageAPIView,
    BazaarCommunicationEnquiryUsageAPIView,

    BazaarChatCreateAPIView,
    BazaarChatListAPIView,
    BazaarChatMessageListAPIView,
    BazaarChatMessageSendAPIView,
    BazaarChatMarkReadAPIView,
)

urlpatterns = [
    path("categories/create/",BazaarCategoryCreateAPIView.as_view(),name="admin-bazaar-category-create"),
    path("categories/", BazaarCategoryListAPIView.as_view(), name="bazaar-categories"),
    path("subcategories/create/",BazaarSubCategoryCreateAPIView.as_view(),name="bazaar-subcategory-create"),
    path("subcategories/",BazaarSubCategoryListAPIView.as_view(),name="bazaar-subcategory-list"),
    path("subcategories/delete/",BazaarSubCategoryDeleteAPIView.as_view(),name="bazaar-subcategory-delete"),
    path("attributes/create/",BazaarAttributeCreateAPIView.as_view(),name="bazaar-attribute-create"),
    path("attributes/",BazaarAttributeListAPIView.as_view(),name="bazaar-attribute-list"),
    path("listings/", BazaarListingListAPIView.as_view(), name="bazaar-listings"),
    path("listings/create/", BazaarListingCreateAPIView.as_view(), name="bazaar-listing-create"),
    path("listings/update/",BazaarListingUpdateAPIView.as_view(),name="bazaar-listing-update"),
    path("listings/detail/", BazaarListingDetailAPIView.as_view(), name="bazaar-listing-detail"),
    path("my-listings/", MyBazaarListingAPIView.as_view(), name="my-bazaar-listings"),
    path("plans/create/",BazaarPlanCreateAPIView.as_view(),name="bazaar-plan-create"),
    path("plans/", BazaarPlanListAPIView.as_view(), name="bazaar-plans"),
    path("pricing/create/",BazaarPricingCreateAPIView.as_view(),name="bazaar-pricing-create"),
    path("pricing/plans/", BazaarPlanPricingListAPIView.as_view(), name="bazaar-plan-pricing-list"),
    path("payment/create/", BazaarCreatePaymentAPIView.as_view(), name="bazaar-payment-create"),
    path("payment/verify/", BazaarVerifyPaymentAPIView.as_view(), name="bazaar-payment-verify"),
    path("enquiries/create/",BazaarEnquiryCreateAPIView.as_view(),name="bazaar-enquiry-create"),
    path("enquiries/",BazaarEnquiryListAPIView.as_view(),name="bazaar-enquiry-list"),
    path("settings/create/",BazaarSettingsCreateAPIView.as_view(), name="bazaar-settings-create"),
    path("settings/",BazaarSettingsListAPIView.as_view(),name="bazaar-settings-list"),
    path("settings/update/",BazaarSettingsUpdateAPIView.as_view(),name="bazaar-settings-update"),



    # Communication Plans
    path("bazaar-communication-plans/create/", BazaarCommunicationPlanCreateAPIView.as_view(), name="bazaar-communication-plan-create"),
    path("bazaar-communication-plans/list/", BazaarCommunicationPlanListAPIView.as_view(), name="bazaar-communication-plan-list"),
    path("bazaar-communication-plans/update/", BazaarCommunicationPlanUpdateAPIView.as_view(), name="bazaar-communication-plan-update"),
    path("bazaar-communication-plans/delete/", BazaarCommunicationPlanDeleteAPIView.as_view(), name="bazaar-communication-plan-delete"),

    # Communication Settings
    path("bazaar-communication-settings/detail/", BazaarCommunicationSettingsDetailAPIView.as_view(), name="bazaar-communication-settings-detail"),
    path("bazaar-communication-settings/update/", BazaarCommunicationSettingsUpdateAPIView.as_view(), name="bazaar-communication-settings-update"),

    # Communication Subscriptions
    path("bazaar-communication-subscriptions/my/", BazaarCommunicationMySubscriptionsAPIView.as_view(), name="bazaar-communication-subscriptions-my"),
    path("bazaar-communication-subscriptions/detail/", BazaarCommunicationSubscriptionDetailAPIView.as_view(), name="bazaar-communication-subscription-detail"),

    # Communication Usage
    path("bazaar-communication-usage/chat/", BazaarCommunicationChatUsageAPIView.as_view(), name="bazaar-communication-chat-usage"),
    path("bazaar-communication-usage/enquiry/", BazaarCommunicationEnquiryUsageAPIView.as_view(), name="bazaar-communication-enquiry-usage"),

    # OLX Chat
    path("chats/create/", BazaarChatCreateAPIView.as_view(), name="bazaar-chat-create",),
    path("chats/", BazaarChatListAPIView.as_view(), name="bazaar-chat-list",),
    path("chats/<int:chat_id>/messages/", BazaarChatMessageListAPIView.as_view(), name="bazaar-chat-messages",),
    path("chats/<int:chat_id>/messages/send/", BazaarChatMessageSendAPIView.as_view(), name="bazaar-chat-message-send",),
    path("chats/<int:chat_id>/read/", BazaarChatMarkReadAPIView.as_view(), name="bazaar-chat-mark-read",),
]