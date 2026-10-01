from django.urls import path
from .views import (
    BranchCategoriesAPIView, 
    BranchCreateView, 
    CompanyBranchesAPIView, 
    CompanyBranchListAPIView, 
    BranchUpdateAPIView, 
    BranchSoftDeleteAPIView, 
    BranchRestoreAPIView
    )

urlpatterns = [
    path('branch/create/', BranchCreateView.as_view()),
    path('company_branches/', CompanyBranchesAPIView.as_view()),
    path("branch-categories/", BranchCategoriesAPIView.as_view()),
    
    path('company/branches-list/', CompanyBranchListAPIView.as_view(), name='company-branches-list'),
    path('branch/update/', BranchUpdateAPIView.as_view(), name='branch-update'),
    path('branch/soft-delete/', BranchSoftDeleteAPIView.as_view(), name='branch-soft-delete'),
    path('branch/restore/', BranchRestoreAPIView.as_view(), name='branch-restore'),
]