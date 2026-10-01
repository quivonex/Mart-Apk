from rest_framework.views import APIView # type: ignore
from rest_framework.response import Response # type: ignore
from rest_framework import status # type: ignore
from django.contrib.auth.hashers import check_password # type: ignore
from django.contrib.auth import get_user_model # type: ignore
from rest_framework_simplejwt.tokens import RefreshToken # type: ignore
from .models import UserAdmin
from .serializers import UserAdminSerializer
from django.core.mail import send_mail # type: ignore
from random import randint
from django.utils import timezone # type: ignore
from .models import UserAdmin, OTP
from datetime import timedelta
from django.utils import timezone # type: ignore
from .models import admin_Role
from .serializers import RoleSerializer


# CREATE ROLE
class CreateRoleView(APIView):
    def post(self, request):
        serializer = RoleSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({
                "message": "Role created successfully",
                "data": serializer.data
            })
        return Response(serializer.errors)


# GET ALL ROLES (ONLY ACTIVE)
class RoleListView(APIView):
    def post(self, request):
        roles = admin_Role.objects.filter(is_active=True)
        serializer = RoleSerializer(roles, many=True)
        return Response({
            "message": "Roles fetched successfully",
            "data": serializer.data
        })


# GET SINGLE ROLE
class RoleDetailView(APIView):
    def post(self, request):
        role_id = request.data.get("id")
        role = admin_Role.objects.filter(id=role_id, is_active=True).first()
        if not role:
            return Response({"message": "Role not found"})
        serializer = RoleSerializer(role)
        return Response({
            "message": "Role fetched successfully",
            "data": serializer.data
        })


# UPDATE ROLE
class UpdateRoleView(APIView):
    def post(self, request):
        role_id = request.data.get("id")
        role = admin_Role.objects.filter(id=role_id, is_active=True).first()
        if not role:
            return Response({"message": "Role not found"})
        serializer = RoleSerializer(role, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({
                "message": "Role updated successfully",
                "data": serializer.data
            })
        return Response(serializer.errors)


# SOFT DELETE ROLE
class SoftDeleteRoleView(APIView):
    def post(self, request):
        role_id = request.data.get("id")
        role = admin_Role.objects.filter(id=role_id).first()
        if not role:
            return Response({"message": "Role not found"})
        role.is_active = False
        role.save()
        return Response({
            "message": "Role deleted successfully (soft delete)"
        })





from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status;
from .serializers import UserAdminSerializer


class UserAdminCreateAPIView(APIView):

    def post(self, request):

        serializer = UserAdminSerializer(data=request.data)

        if not serializer.is_valid():
            return Response({
                "status": False,
                "errors": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        serializer.save()

        return Response({
            "status": True,
            "message": "User Admin created successfully",
            "data": serializer.data
        }, status=status.HTTP_201_CREATED)



User = get_user_model()

class UserListView(APIView):
    permission_classes = []   # जर login required नसेल तर

    def post(self, request):
        users = User.objects.all()
        serializer = UserAdminSerializer(users, many=True)

        return Response({
            "status": "success",
            "count": users.count(),
            "users": serializer.data
        }, status=status.HTTP_200_OK)        






User = get_user_model()

from .models import UserAdmin
from rest_framework_simplejwt.tokens import RefreshToken # type: ignore

class UserAdminLoginAPIView(APIView):

    def post(self, request):

        username = request.data.get("username")
        password = request.data.get("password")
        role = request.data.get("role")

        if not username or not password or not role:
            return Response({
                "status": False,
                "message": "username, password and role required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
           user = UserAdmin.objects.get(username=username, role__role_name=role)
        except UserAdmin.DoesNotExist:
            return Response({
                "status": False,
                "message": "Invalid username or role"
            }, status=status.HTTP_400_BAD_REQUEST)

        if not user.check_password(password):
            return Response({
                "status": False,
                "message": "Invalid password"
            }, status=status.HTTP_400_BAD_REQUEST)

        refresh = RefreshToken.for_user(user)

        return Response({
            "status": True,
            "message": "Login successful",
            "token": {
                "refresh": str(refresh),
                "access": str(refresh.access_token)
            },
            "user": {
                "id": user.id,
                "username": user.username,
                "name": user.name,
                "email": user.email,
                "role": user.role.role_name
            }
        })
    
    
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

class UserAdminLoginAPIView(APIView):

    def post(self, request):

        username = request.data.get("username")
        password = request.data.get("password")

        if not username or not password:
            return Response({
                "status": False,
                "message": "username and password required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = UserAdmin.objects.get(username=username)

        except UserAdmin.DoesNotExist:
            return Response({
                "status": False,
                "message": "Invalid username"
            }, status=status.HTTP_400_BAD_REQUEST)

        if not user.check_password(password):
            return Response({
                "status": False,
                "message": "Invalid password"
            }, status=status.HTTP_400_BAD_REQUEST)

        refresh = RefreshToken.for_user(user)

        return Response({
            "status": True,
            "message": "Login successful",
            "token": {
                "refresh": str(refresh),
                "access": str(refresh.access_token)
            },
            "user": {
                "id": user.id,
                "username": user.username,
                "name": user.name,
                "email": user.email,
                "role": user.role.role_name
            }
        }, status=status.HTTP_200_OK)    


class SendOTPView(APIView):
    permission_classes = []  # public API

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'status':'error', 'msg':'Email is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'status':'error', 'msg':'admin not found'}, status=status.HTTP_404_NOT_FOUND)

        # Generate 6-digit OTP
        otp_code = f"{randint(100000, 999999)}"

        # Save OTP with expiry (5 minutes from now)
        otp_instance = OTP.objects.create(
            user=user,
            otp=otp_code,
            expires_at=timezone.now() + timedelta(minutes=5)
        )

        # Send OTP via email
        send_mail(
            subject='Your OTP Code',
            message=f'Hello {user.name},\n\nYour OTP code is {otp_code}. It will expire in 5 minutes.',
            from_email='your_email@gmail.com',
            recipient_list=[email],
            fail_silently=False
        )

        return Response({'status':'success', 'msg':'OTP sent to email'}, status=status.HTTP_200_OK)
    



class VerifyOTPView(APIView):
    permission_classes = []  # public API

    def post(self, request):
        email = request.data.get('email')
        otp_input = request.data.get('otp')

        if not email or not otp_input:
            return Response({'status':'error', 'msg':'Email and OTP are required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'status':'error', 'msg':'User not found'}, status=status.HTTP_404_NOT_FOUND)

        # Get latest OTP for this user
        otp_instance = OTP.objects.filter(user=user).order_by('-created_at').first()
        if not otp_instance:
            return Response({'status':'error', 'msg':'No OTP found for this user'}, status=status.HTTP_404_NOT_FOUND)

        # 1️⃣ Check if OTP expired
        if timezone.now() > otp_instance.expires_at:
            return Response({'status':'error', 'msg':'OTP expired'}, status=status.HTTP_400_BAD_REQUEST)

        # 2️⃣ Check if OTP matches
        if otp_instance.otp != otp_input:
            return Response({'status':'error', 'msg':'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

        # 3️⃣ OTP verified — optional: delete used OTP
        otp_instance.delete()

        return Response({'status':'success', 'msg':'OTP verified successfully', 'user_id': user.id}, status=status.HTTP_200_OK)    


class OTPResetPasswordView(APIView):
    permission_classes = []  # public API, OTP already verified on frontend

    def post(self, request):
        email = request.data.get('email')
        new_password = request.data.get('new_password')
        confirm_password = request.data.get('confirm_password')

        # 1️⃣ Check required fields
        if not email or not new_password or not confirm_password:
            return Response({'status':'error', 'msg':'Email, new password and confirm password are required'}, status=status.HTTP_400_BAD_REQUEST)

        # 2️⃣ Check password match
        if new_password != confirm_password:
            return Response({'status':'error', 'msg':'New password and confirm password do not match'}, status=status.HTTP_400_BAD_REQUEST)

        # 3️⃣ Validate user
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'status':'error', 'msg':'User not found'}, status=status.HTTP_404_NOT_FOUND)

        # 4️⃣ Set new password
        user.set_password(new_password)

        return Response({'status':'success', 'msg':'Password reset successfully'}, status=status.HTTP_200_OK)    
    




from rest_framework.views import APIView
from rest_framework.response import Response
from .models import UploadImage
from .s3_upload import upload_file_to_s3


class UploadImageView(APIView):
    def post(self, request):
        file = request.FILES.get('image')

        if not file:
            return Response({"status": "error", "message": "No file provided"})

        file_url = upload_file_to_s3(file)

        if not file_url:
            return Response({"status": "error", "message": "Upload failed"})

        image = UploadImage.objects.create(
            image_s3_key=file_url,
            title=request.data.get("title")
        )

        return Response({
            "status": "success",
            "image_url": file_url,
            "id": image.id
        })    


class UploadImageListView(APIView):
    def post(self, request):
        images = UploadImage.objects.filter(is_active=True).order_by('-created_at')

        data = []
        for img in images:
            data.append({
                "id": img.id,
                "image_url": img.image_s3_key,
                "title": img.title,
                "created_at": img.created_at
            })

        return Response({
            "status": "success",
            "count": len(data),
            "data": data
        })        
    


class UploadImageUpdateView(APIView):
    def post(self, request):
        try:
            image_id = request.data.get("id")

            if not image_id:
                return Response({"status": "error", "message": "id is required"})

            image_obj = UploadImage.objects.get(id=image_id)

            # 🔹 Title Update
            title = request.data.get("title")
            if title is not None:
                image_obj.title = title

            # 🔹 Image Replace (optional)
            file = request.FILES.get("image")
            if file:
                file_url = upload_file_to_s3(file)
                if file_url:
                    image_obj.image_s3_key = file_url
                else:
                    return Response({"status": "error", "message": "Image upload failed"})

            image_obj.save()

            return Response({
                "status": "success",
                "message": "Image updated successfully",
                "data": {
                    "id": image_obj.id,
                    "image_url": image_obj.image_s3_key,
                    "title": image_obj.title
                }
            })

        except UploadImage.DoesNotExist:
            return Response({
                "status": "error",
                "message": "Image not found"
            })    


class UploadImageDeleteView(APIView):
    def post(self, request):
        try:
            image_id = request.data.get("id")

            if not image_id:
                return Response({
                    "status": "error",
                    "message": "id is required"
                })

            image = UploadImage.objects.get(id=image_id)

            # 🔹 Soft Delete
            image.is_active = False
            image.save()

            return Response({
                "status": "success",
                "message": "Image deleted successfully"
            })

        except UploadImage.DoesNotExist:
            return Response({
                "status": "error",
                "message": "Image not found"
            })


class UploadImageRestoreView(APIView):
    def post(self, request):
        try:
            image_id = request.data.get("id")

            if not image_id:
                return Response({
                    "status": "error",
                    "message": "id is required"
                })

            image = UploadImage.objects.get(id=image_id)

            # 🔹 Restore (Active करा)
            image.is_active = True
            image.save()

            return Response({
                "status": "success",
                "message": "Image restored successfully",
                "data": {
                    "id": image.id,
                    "image_url": image.image_s3_key,
                    "title": image.title
                }
            })

        except UploadImage.DoesNotExist:
            return Response({
                "status": "error",
                "message": "Image not found"
            })           
            
            
            
            
import time
import requests

from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status


class NearbyPlacesView(APIView):

    def post(self, request):

        lat = request.data.get("lat")
        lng = request.data.get("lng")
        radius = request.data.get("radius", 10000)
        keyword = request.data.get("keyword", "")

        # Validation
        if not lat or not lng:
            return Response(
                {
                    "status": False,
                    "message": "Latitude and Longitude are required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"

        params = {
            "location": f"{lat},{lng}",
            "radius": radius,
            "keyword": keyword,
            "key": settings.GOOGLE_MAPS_API_KEY,
        }

        all_results = []

        try:
            # First Page
            response = requests.get(url, params=params).json()

            if response.get("status") not in ["OK", "ZERO_RESULTS"]:
                return Response(
                    {
                        "status": False,
                        "message": response.get("error_message", response.get("status"))
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            all_results.extend(response.get("results", []))

            next_page_token = response.get("next_page_token")

            # Maximum 2 more pages
            while next_page_token:

                # Google requires a short delay before next_page_token becomes valid
                time.sleep(2)

                response = requests.get(
                    url,
                    params={
                        "pagetoken": next_page_token,
                        "key": settings.GOOGLE_MAPS_API_KEY,
                    },
                ).json()

                if response.get("status") == "OK":
                    all_results.extend(response.get("results", []))
                    next_page_token = response.get("next_page_token")
                else:
                    break

            # Filter only Rating >= 3.5
            filtered_results = [
                place for place in all_results
                if place.get("rating", 0) >= 3.5
            ]

            # Sort by Rating (Highest First)
            filtered_results.sort(
                key=lambda x: x.get("rating", 0),
                reverse=True
            )

            return Response(
                {
                    "status": True,
                    "message": "Nearby places fetched successfully.",
                    "count": len(filtered_results),
                    "results": filtered_results,
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:
            return Response(
                {
                    "status": False,
                    "message": str(e),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )