

from django.urls import path

from .views import CompanyCreateAPIView, CompanyListAPIView, CompanyProductListView, CompanyRetrieveAPIView, CompanyStockAPIView, CompanyUpdateAPIView, CompanyallListAPIView, CompanycountListAPIView, CompanynameListAPIView, CreateCompanyPaymentOrderAPIView, FirstFiveCompaniesAPIView, LowStockProductsAPIView, OwnerNameListView, PaidCompanyCountAPIView, RestoreCompanyAPIView, SoftDeleteCompanyAPIView, SupplierDeleteAPIView, SupplierListAPIView, SupplierUpdateAPIView, UnpaidCompanyPendingAmountAPIView, UserCompanycountListAPIView, VerifyCompanyPaymentAPIView,SupplierCreateAPIView

urlpatterns = [
    
    path('company/create/', CompanyCreateAPIView.as_view(), name='company-create'),
    path('create-company-payment-order/',CreateCompanyPaymentOrderAPIView.as_view(),name='create-company-payment-order'),
    path('verify-payment/', VerifyCompanyPaymentAPIView.as_view(), name='verify-payment'),
    path('company/update/', CompanyUpdateAPIView.as_view(), name='company-update'),
    path('company/list/', CompanyListAPIView.as_view(), name='company-list'),
    path("paid-companies/count/", PaidCompanyCountAPIView.as_view(),name="paid-companies-count"),
    path("unpaid-companies/pending-amount/",UnpaidCompanyPendingAmountAPIView.as_view(),name="unpaid-companies-pending-amount"),
    path('company/single-retrieve/', CompanyRetrieveAPIView.as_view(), name='company-detail'),
    path('company/names/', CompanynameListAPIView.as_view(), name='company-name-list'),
    path('company/all/', CompanyallListAPIView.as_view(), name='company-all-list'),
    path('company/soft-delete/', SoftDeleteCompanyAPIView.as_view(), name='company-soft-delete'),
    path('company/restore/', RestoreCompanyAPIView.as_view(), name='company-restore'),
    path("latest-companies/", FirstFiveCompaniesAPIView.as_view()),
    path('company/', CompanycountListAPIView.as_view(), name='company-list'),
    path('company/user-count/', UserCompanycountListAPIView.as_view(), name='user-company-count'),
    path('company/owner-list/', OwnerNameListView.as_view(), name='owner-list'),
    path('product/company-wise/', CompanyProductListView.as_view()),
    
    path("company/stock/",CompanyStockAPIView.as_view(),name="company-stock"),
    path("company/low-stock/",LowStockProductsAPIView.as_view(),name="company-low-stock"),
    
    
    
    path('suppliers/create/', SupplierCreateAPIView.as_view(), name='supplier-create'),
    path('suppliers/list/', SupplierListAPIView.as_view(), name='supplier-list'),
    path('suppliers/update/', SupplierUpdateAPIView.as_view(), name='supplier-update'),
    path('supplier/delete/', SupplierDeleteAPIView.as_view(), name='supplier-delete'),
]

