from django.urls import path
from .views import SellerCreateView, SellerListView, SellerUpdateView

urlpatterns = [
    path('seller/create/', SellerCreateView.as_view(), name='seller-create'),
    path('seller/list/', SellerListView.as_view(), name='seller-list'),
  path('seller/update/', SellerUpdateView.as_view(), name='seller-update'),
]