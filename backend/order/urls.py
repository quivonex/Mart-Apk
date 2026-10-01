from django.urls import path
from .views import AddressCreateView, AddressListView, AddressUpdateView, AdminOrderListAPIView, CompanySalesAPIView, CreateOrderView, OrderDetailView,  test_shiprocket,get_shipping_rates,create_full_shiprocket_order,track_shipment,cancel_shiprocket_order

urlpatterns = [
    path('create-order/', CreateOrderView.as_view(), name='create_order'),
    path('order-detail/', OrderDetailView.as_view(), name='order_detail'),
    path('admin/orders/', AdminOrderListAPIView.as_view()),
    path('admin/sales/', CompanySalesAPIView.as_view()),
    path('address/create/', AddressCreateView.as_view(), name='address-create'),
    # path('addresses/', AddressListView.as_view(), name='address-list'),
    path('address/list/', AddressListView.as_view(), name='address-list'),
    path('address/update/', AddressUpdateView.as_view(), name='address-update'),
    path('test-shiprocket/', test_shiprocket),
    path('shipping-rates/', get_shipping_rates),
    path('create-shiprocket-order/', create_full_shiprocket_order),
    path('track-shipment/', track_shipment),
    path('cancel-order/', cancel_shiprocket_order)
]