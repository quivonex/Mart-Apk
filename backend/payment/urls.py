from django.urls import path

from .views import (
    BazaarCommunicationCreateOrderAPIView,
    BazaarCommunicationPaymentHistoryAPIView,
    BazaarCommunicationVerifyPaymentAPIView,
    CreatePaymentSettingAPIView,
    CustomerMySubscriptionsAPIView,
    CustomerSubscriptionPlanCreateAPIView,
    CustomerSubscriptionPlanListAPIView,
    CustomerSubscriptionPlanUpdateAPIView,
    CustomerSubscriptionVerifyPaymentAPIView,
    PropertySubscriptionCreateOrderAPIView,
    PropertySubscriptionPlanCreateAPIView,
    PropertySubscriptionPlanListAPIView,
    PropertySubscriptionPlanUpdateAPIView,
    PropertySubscriptionVerifyAPIView,
    UpdateCompanyRegistrationAmountAPIView,
    CreateRazorpayOrderAPIView,
    VerifyRazorpayPaymentAPIView,
    CustomerSubscriptionCreateOrderAPIView,
)

urlpatterns = [

    # Payment Setting
    path("payment-setting/create/",CreatePaymentSettingAPIView.as_view(),name="payment-setting-create"),
    path("payment-setting/company-registration/update/",UpdateCompanyRegistrationAmountAPIView.as_view(),name="company-registration-amount-update"),

    # Razorpay
    path("razorpay/create-order/",CreateRazorpayOrderAPIView.as_view(),name="razorpay-create-order"),
    path("razorpay/verify-payment/",VerifyRazorpayPaymentAPIView.as_view(),name="razorpay-verify-payment"),
    
    path("property-subscription/create-order/",PropertySubscriptionCreateOrderAPIView.as_view(),name="property-subscription-create-order"),
    path("property-subscription/verify/",PropertySubscriptionVerifyAPIView.as_view(),name="property-subscription-verify"),

    path("property-subscription-plan/create/",PropertySubscriptionPlanCreateAPIView.as_view(),name="property-subscription-plan-create"),
    path("property-subscription-plan/list/",PropertySubscriptionPlanListAPIView.as_view(),name="property-subscription-plan-list"),
    path("property-subscription-plan/update/",PropertySubscriptionPlanUpdateAPIView.as_view(),name="property-subscription-plan-update"),
    


    path("customer-subscription-plans/",CustomerSubscriptionPlanListAPIView.as_view(),name="customer-subscription-plan-list"),
    path("customer-subscription-plans/update/",CustomerSubscriptionPlanUpdateAPIView.as_view(),name="customer-subscription-plan-update"),
    path("customer-subscription-plans/create/",CustomerSubscriptionPlanCreateAPIView.as_view(),name="customer-subscription-plan-create"),
    path("customer-subscription/create-order/",CustomerSubscriptionCreateOrderAPIView.as_view(),name="customer-subscription-create-order"),
    path("customer-subscription/verify-payment/",CustomerSubscriptionVerifyPaymentAPIView.as_view(),name="customer-subscription-verify-payment"),
    path("customer-subscriptions/my/",CustomerMySubscriptionsAPIView.as_view(),name="customer-my-subscriptions"),
    
    
    # Bazaar Communication Payments
    path("bazaar-communication/create-order/", BazaarCommunicationCreateOrderAPIView.as_view(), name="bazaar-communication-create-order"),
    path("bazaar-communication/verify-payment/", BazaarCommunicationVerifyPaymentAPIView.as_view(), name="bazaar-communication-verify-payment"),
    path("bazaar-communication/history/", BazaarCommunicationPaymentHistoryAPIView.as_view(), name="bazaar-communication-payment-history"),

]
