from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from .models import EmailOTP
from .serializers import UserListSerializer, UserRegisterSerializer, UserProfileSerializer
from .utils import generate_otp, send_otp_email

User = get_user_model()


# 🔹 1. SEND OTP
class SendOTPView(APIView):
    def post(self, request):
        email = request.data.get("email")

        if not email:
            return Response({"error": "Email required"}, status=400)

        otp = generate_otp()

        # update or create OTP
        EmailOTP.objects.update_or_create(
            email=email,
            defaults={
                "otp": otp,
                "is_verified": False,
                "created_at": timezone.now()
            }
        )

        send_otp_email(email, otp)

        return Response({"message": "OTP sent successfully"})


# 🔹 2. VERIFY OTP
class VerifyOTPView(APIView):
    def post(self, request):
        email = request.data.get("email")
        otp = request.data.get("otp")

        otp_obj = EmailOTP.objects.filter(email=email).first()

        if not otp_obj:
            return Response({"error": "OTP not found"}, status=400)

        if otp_obj.is_expired():
            return Response({"error": "OTP expired"}, status=400)

        if otp_obj.otp != otp:
            return Response({"error": "Invalid OTP"}, status=400)

        otp_obj.is_verified = True
        otp_obj.save()

        return Response({"message": "OTP verified successfully"})


# 🔹 3. REGISTER
class RegisterUserView(APIView):
    def post(self, request):
        email = request.data.get("email")

        otp_obj = EmailOTP.objects.filter(email=email, is_verified=True).first()

        if not otp_obj:
            return Response({"error": "Email not verified"}, status=400)

        serializer = UserRegisterSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()

            # cleanup
            otp_obj.delete()

            return Response({"message": "User registered successfully"})

        return Response(serializer.errors, status=400)

# # 🔹 4. LOGIN (NO SERIALIZER)
# class LoginView(APIView):
#     def post(self, request):
#         username = request.data.get("username")
#         password = request.data.get("password")
#         role_name = request.data.get("role")   # optional

#         if not username or not password:
#             return Response(
#                 {"error": "Username and password required"},
#                 status=400
#             )

#         user = User.objects.filter(username__iexact=username).first()

#         if not user or not user.check_password(password):
#             return Response(
#                 {"error": "Invalid credentials"},
#                 status=400
#             )

#         if not user.is_email_verified:
#             return Response(
#                 {"error": "Email not verified"},
#                 status=400
#             )

#         # role दिला असेल तरच check कर
#         if user.role and role_name and user.role.role_name != role_name:
#             return Response(
#                 {"error": "Invalid role selected"},
#                 status=403
#             )

#         refresh = RefreshToken.for_user(user)

#         return Response({
#             "message": "Login successful",
#             "access_token": str(refresh.access_token),
#             "refresh_token": str(refresh),
#             "user": {
#                 "id": user.id,
#                 "username": user.username,
#                 "email": user.email,
#                 "role": user.role.role_name if user.role else None
#             }
#         })

# from django.contrib.auth import get_user_model
# from django.db.models import Q
# from rest_framework.views import APIView
# from rest_framework.response import Response
# from rest_framework_simplejwt.tokens import RefreshToken

# User = get_user_model()    
    
# class LoginView(APIView):

#     def post(self, request):

#         username = request.data.get("username", "").strip()
#         password = request.data.get("password", "")
#         role_name = request.data.get("role")

#         if not username or not password:
#             return Response(
#                 {"error": "Username/email and password required"},
#                 status=400
#             )

#         # Username किंवा Email ने user शोधा
#         user = User.objects.filter(
#             Q(username__iexact=username) |
#             Q(email__iexact=username)
#         ).first()

#         if not user or not user.check_password(password):
#             return Response(
#                 {"error": "Invalid username/email or password"},
#                 status=400
#             )

#         # Email verification
#         if not user.is_email_verified:
#             return Response(
#                 {"error": "Email not verified"},
#                 status=400
#             )

#         # Role validation
#         if user.role and role_name and user.role.role_name != role_name:
#             return Response(
#                 {"error": "Invalid role selected"},
#                 status=403
#             )

#         refresh = RefreshToken.for_user(user)

#         return Response({
#             "message": "Login successful",
#             "access_token": str(refresh.access_token),
#             "refresh_token": str(refresh),

#             "user": {
#                 "id": user.id,
#                 "username": user.username,
#                 "email": user.email,
#                 "role": user.role.role_name if user.role else None
#             }
#         })

from django.contrib.auth import get_user_model
from django.db.models import Q

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import FCMToken


User = get_user_model()


class LoginView(APIView):

    def post(self, request):

        username = request.data.get("username", "").strip()
        password = request.data.get("password", "")
        role_name = request.data.get("role")

        # FCM Token
        fcm_token = request.data.get("fcm_token")

        # --------------------------------------------------
        # Username / Password Validation
        # --------------------------------------------------

        if not username or not password:
            return Response(
                {
                    "error": "Username/email and password required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # --------------------------------------------------
        # Find User by Username or Email
        # --------------------------------------------------

        user = User.objects.filter(
            Q(username__iexact=username) |
            Q(email__iexact=username)
        ).first()

        if not user or not user.check_password(password):
            return Response(
                {
                    "error": "Invalid username/email or password"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # --------------------------------------------------
        # Email Verification
        # --------------------------------------------------

        if not user.is_email_verified:
            return Response(
                {
                    "error": "Email not verified"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # --------------------------------------------------
        # Role Validation
        # --------------------------------------------------

        if (
            user.role
            and role_name
            and user.role.role_name != role_name
        ):
            return Response(
                {
                    "error": "Invalid role selected"
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # --------------------------------------------------
        # Generate JWT Tokens
        # --------------------------------------------------

        refresh = RefreshToken.for_user(user)

        # --------------------------------------------------
        # Save / Update FCM Token
        # --------------------------------------------------

        fcm_token_saved = False

        if fcm_token:

            FCMToken.objects.update_or_create(
                user=user,
                defaults={
                    "token": fcm_token,
                    "device_type": "web",
                    "is_active": True
                }
            )

            fcm_token_saved = True

        # --------------------------------------------------
        # Login Response
        # --------------------------------------------------

        return Response(
            {
                "message": "Login successful",

                "access_token": str(
                    refresh.access_token
                ),

                "refresh_token": str(
                    refresh
                ),

                "fcm_token_saved": fcm_token_saved,

                "user": {
                    "id": user.id,
                    "username": user.username,
                    "email": user.email,
                    "role": (
                        user.role.role_name
                        if user.role
                        else None
                    )
                }
            },
            status=status.HTTP_200_OK
        )
class ForgotPasswordSendOTPView(APIView):
    def post(self, request):
        email = request.data.get("email")

        if not email:
            return Response({"error": "Email required"}, status=400)

        user = User.objects.filter(email__iexact=email).first()

        if not user:
            return Response({"error": "User not found"}, status=404)

        otp = generate_otp()

        EmailOTP.objects.update_or_create(
            email=email,
            defaults={
                "otp": otp,
                "is_verified": False,
                "created_at": timezone.now()
            }
        )

        send_otp_email(email, otp)

        return Response({"message": "OTP sent successfully"})



class ForgotPasswordVerifyOTPView(APIView):
    def post(self, request):
        email = request.data.get("email")
        otp = request.data.get("otp")

        otp_obj = EmailOTP.objects.filter(email=email).first()

        if not otp_obj:
            return Response({"error": "OTP not found"}, status=400)

        if otp_obj.is_expired():
            return Response({"error": "OTP expired"}, status=400)

        if otp_obj.otp != otp:
            return Response({"error": "Invalid OTP"}, status=400)

        otp_obj.is_verified = True
        otp_obj.save()

        return Response({"message": "OTP verified"})





class ResetPasswordView(APIView):
    def post(self, request):
        email = request.data.get("email")
        password = request.data.get("password")
        confirm_password = request.data.get("confirm_password")

        # Required fields check
        if not email or not password or not confirm_password:
            return Response(
                {"error": "Email, password and confirm password required"},
                status=400
            )

        # Password match check
        if password != confirm_password:
            return Response(
                {"error": "Passwords do not match"},
                status=400
            )

        # OTP verified check
        otp_obj = EmailOTP.objects.filter(email=email, is_verified=True).first()

        if not otp_obj:
            return Response({"error": "OTP not verified"}, status=400)

        # User check
        user = User.objects.filter(email__iexact=email).first()

        if not user:
            return Response({"error": "User not found"}, status=404)

        # Set new password
        user.set_password(password)
        user.save()

        # Cleanup OTP
        otp_obj.delete()

        return Response({"message": "Password reset successful"})
    



from rest_framework.views import APIView
from rest_framework.response import Response

class UserListView(APIView):
    def post(self, request):
        users = User.objects.all().order_by('-id')
        serializer = UserListSerializer(users, many=True)
        return Response({
            "status": "success",
            "data": serializer.data
        })    
        
class UserCountView(APIView):

    def post(self, request):

        user_count = User.objects.count()

        return Response({
            "status": "success",
            "count": user_count
        })        
        
        
class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = UserProfileSerializer(request.user)

        return Response({
            "status": "success",
            "data": serializer.data
        }, status=status.HTTP_200_OK)        



# views.py
from rest_framework.permissions import IsAuthenticated
from .models import InstagramReel
from .serializers import InstagramReelSerializer
from rest_framework_simplejwt.authentication import JWTAuthentication # type: ignore

# Create
class CreateInstagramReelAPI(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = InstagramReelSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(user=request.user)
            return Response(
                {
                    "success": True,
                    "message": "Instagram reel created successfully",
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )
        return Response(
            {
                "success": False,
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )


# LIST API
class InstagramReelListAPI(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        reels = InstagramReel.objects.filter(
            user=request.user
        ).order_by("-created_at")

        serializer = InstagramReelSerializer(
            reels,
            many=True
        )

        return Response(
            {
                "success": True,
                "count": reels.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )


# LIST API
class InstagramReelListAllAPI(APIView):

    def post(self, request):

        reels = InstagramReel.objects.filter(
            is_active=True
        ).order_by("-created_at")

        serializer = InstagramReelSerializer(
            reels,
            many=True
        )

        return Response(
            {
                "success": True,
                "count": reels.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )


# SOFT DELETE API
class SoftDeleteInstagramReelAPI(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        reel_id = request.data.get("id")

        try:
            reel = InstagramReel.objects.get(
                id=reel_id,
                user=request.user,
                is_active=True
            )

            reel.is_active = False
            reel.save()

            return Response(
                {
                    "success": True,
                    "message": "Instagram reel deleted successfully"
                },
                status=status.HTTP_200_OK
            )

        except InstagramReel.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Instagram reel not found"
                },
                status=status.HTTP_404_NOT_FOUND
            )


# RESTORE API
class RestoreInstagramReelAPI(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        reel_id = request.data.get("id")

        try:
            reel = InstagramReel.objects.get(
                id=reel_id,
                user=request.user,
                is_active=False
            )

            reel.is_active = True
            reel.save()

            return Response(
                {
                    "success": True,
                    "message": "Instagram reel restored successfully"
                },
                status=status.HTTP_200_OK
            )

        except InstagramReel.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Instagram reel not found"
                },
                status=status.HTTP_404_NOT_FOUND
            )