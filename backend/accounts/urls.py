from django.urls import path
from .views import *

urlpatterns = [
    path('send-otp/', SendOTPView.as_view()),
    path('verify-otp/', VerifyOTPView.as_view()),
    path('register/', RegisterUserView.as_view()),
    path('profile/', UserProfileView.as_view(), name='user-profile'),
    path('login/', LoginView.as_view()),
    path('users/', UserListView.as_view(), name='user-list'),
    path('user-count/', UserCountView.as_view(), name='user-count'),
    path('forgot-password/send-otp/', ForgotPasswordSendOTPView.as_view()),
    path('forgot-password/verify-otp/', ForgotPasswordVerifyOTPView.as_view()),
    path('forgot-password/reset/', ResetPasswordView.as_view()),
    
    path("instagram-reel/create/",CreateInstagramReelAPI.as_view(),name="create-instagram-reel"),
    path("instagram-reel/list/",InstagramReelListAPI.as_view(),name="instagram-reels"),
    path("instagram-reel/list-all/",InstagramReelListAllAPI.as_view(),name="instagram-reels-all"),
    path("instagram-reel/soft-delete/",SoftDeleteInstagramReelAPI.as_view(),name="soft-delete-instagram-reel"),
    path("instagram-reel/restore/",RestoreInstagramReelAPI.as_view(),name="restore-instagram-reel"),
]
