from django.urls import path

from .views import PropertyPDFExtractionAPIView


urlpatterns = [
    path("extract-property/", PropertyPDFExtractionAPIView.as_view(), name="extract-property"),
]