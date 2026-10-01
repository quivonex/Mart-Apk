from django.urls import path
from .views import ContactUsCreateAPIView, ContactUsListAPIView

urlpatterns = [
    path('contact-us/', ContactUsCreateAPIView.as_view(), name='contact-us'),
    path('contact-us-list/', ContactUsListAPIView.as_view(), name='contact-us-list'),
]