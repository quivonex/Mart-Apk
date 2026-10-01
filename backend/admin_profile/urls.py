from django.urls import path # type: ignore
from .views import CreateRoleView, NearbyPlacesView, UploadImageDeleteView, UploadImageListView, UploadImageRestoreView, UploadImageUpdateView, UploadImageView, UserAdminLoginAPIView, OTPResetPasswordView, UserAdminCreateAPIView, RoleDetailView, RoleListView, SendOTPView, SoftDeleteRoleView, UpdateRoleView, UserListView, VerifyOTPView

urlpatterns = [
    
    path('roles/create/', CreateRoleView.as_view()),
    path('roles/list/', RoleListView.as_view()),
    path('roles/detail/', RoleDetailView.as_view()),
    path('roles/update/', UpdateRoleView.as_view()),
    path('roles/soft_delete/', SoftDeleteRoleView.as_view()),
    
    path('admin/create/', UserAdminCreateAPIView.as_view(), name='user-register'),
    path('admin/login/', UserAdminLoginAPIView.as_view(), name='user-login'),
    path('admins/', UserListView.as_view(), name='user-list'),
    path('admin/send-otp/', SendOTPView.as_view(), name='send-otp'),
    path('admin/verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('admin/reset-password/', OTPResetPasswordView.as_view(), name='otp-reset-password'),
    
    path('upload_image/', UploadImageView.as_view()),
    path('upload_image_list/', UploadImageListView.as_view()),
    path('upload_image_update/', UploadImageUpdateView.as_view()),
    path('upload_image_delete/', UploadImageDeleteView.as_view()),
    path('upload_image_restore/', UploadImageRestoreView.as_view()),
    
    path("places/nearby/",NearbyPlacesView.as_view(),name="nearby-places"),
]
