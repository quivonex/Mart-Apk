from django.urls import path
from .views import CompanyFranchisePlanAPIView, FranchiseCreateAPIView, FranchiseListAPIView, FranchisePlanCreateAPIView, FranchisePlanRetrieveAPIView, FranchisePublicListAPIView, GenerateReferralLinkAPIView

urlpatterns = [
    path('franchise/create/', FranchiseCreateAPIView.as_view(),name='franchise-create'),
    path('franchise/list/', FranchiseListAPIView.as_view(), name='franchise-list'),
    path('franchise/public-list/', FranchisePublicListAPIView.as_view(), name='franchise-public-list'),
    path('franchise-plan/create/',FranchisePlanCreateAPIView.as_view(),name='franchise-plan-create'),
    path('franchise-plan/retrieve/',FranchisePlanRetrieveAPIView.as_view(),name='franchise-plan-retrieve'),
    path('product-franchise-plans/', CompanyFranchisePlanAPIView.as_view(), name='company-franchise-plans'),
    path("generate_referral_link/",GenerateReferralLinkAPIView.as_view(),name="generate_referral_link",),
]