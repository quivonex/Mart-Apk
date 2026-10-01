from django.urls import path

from .views import (

ShiprocketDeliveryWebhookAPIView
)
urlpatterns = [

   
    path(
    "shiprocket/delivery-webhook/",
    ShiprocketDeliveryWebhookAPIView.as_view(),
    name="shiprocket-delivery-webhook"
),

]