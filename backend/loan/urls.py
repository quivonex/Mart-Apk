from django.urls import path

from .views import (
    LoanEnquiryCreateAPIView,
    LoanEnquiryListAPIView
)


urlpatterns = [

    path("loan-enquiry/create/",LoanEnquiryCreateAPIView.as_view(),name="loan-enquiry-create"),
    path("loan-enquiry/list/",LoanEnquiryListAPIView.as_view(),name="loan-enquiry-list"),
    

]