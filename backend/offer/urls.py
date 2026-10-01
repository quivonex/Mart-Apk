from django.urls import path # type: ignore
from .views import (
    CreateOfferView,
    OfferAutoFilterAPIView,
    OfferListView,
    OfferListallView,
    OfferDetailView,
    UpdateOfferView,
    DeleteOfferView,
    SoftDeleteOfferView,
    RestoreOfferView,
    ApplyOfferToProductAPIView,
    RemoveOfferFromProductAPIView,
    
    CreateCompanyOfferView,
    CompanyOfferListView,
    CompanyOfferDetailView,
    CompanyOfferUpdateView,
    CompanySoftDeleteOfferView,
    CompanyRestoreOfferView,
    CompanyHardDeleteOfferView
)

urlpatterns = [

    # NO AUTH
    path('offers/create/', CreateOfferView.as_view()),
    path('offers/list/', OfferListView.as_view()),
    path('offers/listall/', OfferListallView.as_view()),
    path('offers/single_retrieve/', OfferDetailView.as_view()),
    path('offers/update/', UpdateOfferView.as_view()),
    path('offers/delete/', DeleteOfferView.as_view()),
    path('offers/soft-delete/', SoftDeleteOfferView.as_view()),
    path('offers/restore/', RestoreOfferView.as_view()),
    
    # AUTH (LOGIN REQUIRED)
    path('offers/apply-to-product/', ApplyOfferToProductAPIView.as_view(), name='apply-offer-to-product'),
    path('offers/remove-from-product/', RemoveOfferFromProductAPIView.as_view(), name='remove-offer-from-product'),
    
    # AUTH (COMPANY CAN MANAGE THEIR INDIVIDUAL OFFERS)
    path('company/offers/create/', CreateCompanyOfferView.as_view(), name='create-company-offer'),
    path('company/offers/list/', CompanyOfferListView.as_view(), name='company-offer-list'),
    path('company/offers/single_retrieve/', CompanyOfferDetailView.as_view(), name='company-offer-detail'),
    path('company/offers/update/', CompanyOfferUpdateView.as_view(), name='company-offer-update'),
    path('company/offers/soft-delete/', CompanySoftDeleteOfferView.as_view(), name='company-offer-soft-delete'),
    path('company/offers/restore/', CompanyRestoreOfferView.as_view(), name='company-offer-restore'),
    path('company/offers/hard-delete/', CompanyHardDeleteOfferView.as_view(), name='company-offer-hard-delete'),
    path('offers/filter-options/', OfferAutoFilterAPIView.as_view(), name='offer-filter-options'),
]