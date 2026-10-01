


from django.urls import path
from .views import (
    CompanyAgreementCreateAPIView,
    CompanyAgreementListAPIView,
    CompanyAgreementStatusAPIView,
    MarketingPartnerAgreementCreateAPIView,  
    MarketingPartnerAgreementStatusAPIView,
    MyCompanyApprovedAgreementAPIView,
    MarketingPartnerAgreementListAPIView,
    MyMarketingPartnerAgreementListAPIView
)
urlpatterns = [

path('company-agreement/create/',CompanyAgreementCreateAPIView.as_view(),name='company-agreement-create'),
path('company-agreement/list/',CompanyAgreementListAPIView.as_view(),name='company-agreement-list'),
path('company-agreement/approve/reject/',CompanyAgreementStatusAPIView.as_view(),name='company-agreement-approve'),
path("company-agreement/my-approved/",MyCompanyApprovedAgreementAPIView.as_view(),name="my-company-approved-agreement"),

path('marketing-partner-agreement/create/',MarketingPartnerAgreementCreateAPIView.as_view(),name='marketing-partner-agreement-create'),
path("marketing-partner-agreement/approve/reject/",MarketingPartnerAgreementStatusAPIView.as_view(),name="marketing-partner-agreement-approve"),
path("marketing-partner-agreement/list/",MarketingPartnerAgreementListAPIView.as_view(),name="marketing-partner-agreement-list"),
path("marketing-partner-agreement/my/",MyMarketingPartnerAgreementListAPIView.as_view(),name="my-marketing-partner-agreement"),
]