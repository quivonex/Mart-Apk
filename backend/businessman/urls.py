from django.urls import path

from .views import BusinessmanCSVUploadAPIView, BusinessmanEmailSendAPIView


urlpatterns = [

    path('businessman/csv-upload/',BusinessmanCSVUploadAPIView.as_view(),name='businessman-csv-upload'),
    path('businessman/send-email/',BusinessmanEmailSendAPIView.as_view(),name='businessman-send-email'),

]