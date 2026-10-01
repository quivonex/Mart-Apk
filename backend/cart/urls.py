from django.urls import path # type: ignore
from .views import AddToCartView, CartListView, DeleteCartItemView

urlpatterns = [
    path('cart/add/', AddToCartView.as_view()),
    path('cart/list/', CartListView.as_view()),
    path('cart/delete/', DeleteCartItemView.as_view(), name='delete-cart-item') # type: ignore
]