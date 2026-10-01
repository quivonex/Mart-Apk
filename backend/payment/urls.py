from django.urls import path

from .views import (
    CreatePaymentSettingAPIView,
    PropertySubscriptionCreateOrderAPIView,
    PropertySubscriptionPlanCreateAPIView,
    PropertySubscriptionPlanListAPIView,
    PropertySubscriptionPlanUpdateAPIView,
    PropertySubscriptionVerifyAPIView,
    UpdateCompanyRegistrationAmountAPIView,
    CreateRazorpayOrderAPIView,
    VerifyRazorpayPaymentAPIView,
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
    

]
