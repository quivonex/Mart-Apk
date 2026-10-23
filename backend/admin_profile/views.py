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
from django.utils import timezone
from django.db import transaction

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import CustomerSubscription


class NearbyPlacesView(APIView):

    def post(self, request):

        user = request.user

        # =====================================================
        # 1. LOGIN CHECK
        # =====================================================

        if not user or not user.is_authenticated:
            return Response(
                {
                    "status": False,
                    "message": "Authentication required."
                },
                status=status.HTTP_401_UNAUTHORIZED
            )

        # =====================================================
        # 2. GET REQUEST DATA
        # =====================================================

        lat = request.data.get("lat")
        lng = request.data.get("lng")
        radius = request.data.get("radius", 10000)
        keyword = request.data.get("keyword", "")

        # =====================================================
        # 3. VALIDATION
        # =====================================================

        if lat in [None, ""] or lng in [None, ""]:
            return Response(
                {
                    "status": False,
                    "message": "Latitude and Longitude are required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            lat = float(lat)
            lng = float(lng)
            radius = int(radius)

        except (ValueError, TypeError):
            return Response(
                {
                    "status": False,
                    "message": "Invalid latitude, longitude or radius."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # 4. GET ACTIVE SUBSCRIPTION
        # =====================================================

        now = timezone.now()

        subscription = (
            CustomerSubscription.objects
            .select_related("plan")
            .filter(
                user=user,
                is_active=True,
                start_date__lte=now,
                end_date__gte=now
            )
            .order_by("-created_at")
            .first()
        )

        # =====================================================
        # 5. SUBSCRIPTION CHECK
        # =====================================================

        if not subscription:

            return Response(
                {
                    "status": False,
                    "message": "No active subscription found.",
                    "subscription_required": True
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # =====================================================
        # 6. CHECK REMAINING ENQUIRIES
        # =====================================================

        remaining = max(
            subscription.enquiry_limit - subscription.enquiry_used,
            0
        )

        if remaining <= 0:

            return Response(
                {
                    "status": False,
                    "message": "Your subscription enquiry limit has been exhausted.",
                    "subscription_required": True,
                    "subscription": {
                        "plan_name": subscription.plan.name,
                        "enquiry_limit": subscription.enquiry_limit,
                        "enquiry_used": subscription.enquiry_used,
                        "remaining_enquiries": 0,
                        "start_date": subscription.start_date,
                        "end_date": subscription.end_date
                    }
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # =====================================================
        # 7. GOOGLE PLACES API
        # =====================================================

        url = (
            "https://maps.googleapis.com/maps/api/place/"
            "nearbysearch/json"
        )

        params = {
            "location": f"{lat},{lng}",
            "radius": radius,
            "keyword": keyword,
            "key": settings.GOOGLE_MAPS_API_KEY,
        }

        all_results = []

        try:

            # =================================================
            # FIRST PAGE
            # =================================================

            google_response = requests.get(
                url,
                params=params,
                timeout=15
            )

            google_response.raise_for_status()

            response_data = google_response.json()

            google_status = response_data.get("status")

            if google_status not in ["OK", "ZERO_RESULTS"]:

                return Response(
                    {
                        "status": False,
                        "message": response_data.get(
                            "error_message",
                            google_status
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            all_results.extend(
                response_data.get("results", [])
            )

            next_page_token = response_data.get(
                "next_page_token"
            )

            # =================================================
            # NEXT PAGES
            # =================================================

            page_count = 1

            while next_page_token and page_count < 3:

                # Google requires a short delay
                time.sleep(2)

                next_response = requests.get(
                    url,
                    params={
                        "pagetoken": next_page_token,
                        "key": settings.GOOGLE_MAPS_API_KEY,
                    },
                    timeout=15
                )

                next_response.raise_for_status()

                next_data = next_response.json()

                if next_data.get("status") == "OK":

                    all_results.extend(
                        next_data.get("results", [])
                    )

                    next_page_token = next_data.get(
                        "next_page_token"
                    )

                    page_count += 1

                else:
                    break

            # =================================================
            # 8. FILTER RATING >= 3.5
            # =================================================

            filtered_results = [
                place
                for place in all_results
                if float(place.get("rating", 0) or 0) >= 3.5
            ]

            # =================================================
            # 9. SORT BY RATING
            # =================================================

            filtered_results.sort(
                key=lambda x: float(
                    x.get("rating", 0) or 0
                ),
                reverse=True
            )

            # =================================================
            # 10. INCREASE SUBSCRIPTION USAGE
            # =================================================

            with transaction.atomic():

                subscription = (
                    CustomerSubscription.objects
                    .select_for_update()
                    .get(
                        id=subscription.id,
                        user=user
                    )
                )

                current_remaining = max(
                    subscription.enquiry_limit
                    - subscription.enquiry_used,
                    0
                )

                if current_remaining <= 0:

                    return Response(
                        {
                            "status": False,
                            "message": (
                                "Your subscription enquiry "
                                "limit has been exhausted."
                            ),
                            "subscription_required": True
                        },
                        status=status.HTTP_403_FORBIDDEN
                    )

                subscription.enquiry_used += 1
                subscription.save(
                    update_fields=["enquiry_used"]
                )

            # =================================================
            # 11. NEW REMAINING COUNT
            # =================================================

            remaining_enquiries = max(
                subscription.enquiry_limit
                - subscription.enquiry_used,
                0
            )

            # =================================================
            # 12. SUCCESS RESPONSE
            # =================================================

            return Response(
                {
                    "status": True,
                    "message": "Nearby places fetched successfully.",

                    "subscription": {
                        "plan_name": subscription.plan.name,
                        "enquiry_limit": subscription.enquiry_limit,
                        "enquiry_used": subscription.enquiry_used,
                        "remaining_enquiries": remaining_enquiries,
                        "start_date": subscription.start_date,
                        "end_date": subscription.end_date,
                    },

                    "search": {
                        "latitude": lat,
                        "longitude": lng,
                        "radius": radius,
                        "keyword": keyword
                    },

                    "count": len(filtered_results),

                    "results": filtered_results
                },
                status=status.HTTP_200_OK
            )

        # =====================================================
        # 13. REQUEST / GOOGLE ERROR
        # =====================================================

        except requests.exceptions.RequestException as e:

            return Response(
                {
                    "status": False,
                    "message": "Unable to fetch nearby places.",
                    "error": str(e)
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        except Exception as e:

            return Response(
                {
                    "status": False,
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
            
            
            

from .models import CustomerSubscriptionPlan
from .serializers import CustomerSubscriptionPlanSerializer


class CustomerSubscriptionPlanCreateAPIView(APIView):

    def post(self, request):

        serializer = CustomerSubscriptionPlanSerializer(
            data=request.data
        )

        if serializer.is_valid():

            plan = serializer.save()

            return Response(
                {
                    "status": True,
                    "message": "Subscription plan created successfully.",
                    "data": CustomerSubscriptionPlanSerializer(
                        plan
                    ).data
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "status": False,
                "message": "Validation failed.",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )            
        
        
class CustomerSubscriptionPlanListAPIView(APIView):



    def get(self, request):

        plans = CustomerSubscriptionPlan.objects.filter(
            is_active=True
        ).order_by("-created_at")

        serializer = CustomerSubscriptionPlanSerializer(
            plans,
            many=True
        )

        return Response(
            {
                "status": True,
                "message": "Subscription plans fetched successfully.",
                "count": plans.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )        
        
        
        

import razorpay

from decimal import Decimal

from django.conf import settings

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import CustomerSubscriptionPlan


class CustomerSubscriptionCreateOrderAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        # 1. Get plan ID
        plan_id = request.data.get("plan_id")

        if not plan_id:
            return Response(
                {
                    "status": False,
                    "message": "plan_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 2. Validate plan ID
        try:
            plan_id = int(plan_id)

            if plan_id <= 0:
                raise ValueError

        except (ValueError, TypeError):
            return Response(
                {
                    "status": False,
                    "message": "Invalid plan_id."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 3. Get active plan
        try:
            plan = CustomerSubscriptionPlan.objects.get(
                id=plan_id,
                is_active=True
            )

        except CustomerSubscriptionPlan.DoesNotExist:
            return Response(
                {
                    "status": False,
                    "message": "Subscription plan not found or inactive."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # 4. Validate price
        if plan.price <= Decimal("0.00"):
            return Response(
                {
                    "status": False,
                    "message": "Plan price must be greater than zero."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 5. Initialize Razorpay
        try:
            client = razorpay.Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET
                )
            )

            # Amount must be in paise
            amount = int(plan.price * 100)

            # 6. Create Razorpay order
            order_data = {
                "amount": amount,
                "currency": "INR",
                "receipt": f"sub_{request.user.id}_{plan.id}",
                "notes": {
                    "user_id": str(request.user.id),
                    "plan_id": str(plan.id),
                    "plan_name": plan.name
                }
            }

            razorpay_order = client.order.create(
                data=order_data
            )

            # 7. Return order details
            return Response(
                {
                    "status": True,
                    "message": "Razorpay order created successfully.",
                    "data": {
                        "order_id": razorpay_order["id"],
                        "razorpay_key": settings.RAZORPAY_KEY_ID,
                        "amount": razorpay_order["amount"],
                        "currency": razorpay_order["currency"],
                        "plan": {
                            "id": plan.id,
                            "name": plan.name,
                            "price": str(plan.price),
                            "enquiry_limit": plan.enquiry_limit,
                            "duration_days": plan.duration_days
                        }
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception:
            return Response(
                {
                    "status": False,
                    "message": "Unable to create Razorpay order."
                },
                status=status.HTTP_502_BAD_GATEWAY
            )
        
        
        
        

from .models import (
    CustomerSubscriptionPlan,
    CustomerSubscription,
    CustomerSubscriptionPayment,
)


class CustomerSubscriptionVerifyPaymentAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        razorpay_order_id = request.data.get(
            "razorpay_order_id"
        )
        razorpay_payment_id = request.data.get(
            "razorpay_payment_id"
        )
        razorpay_signature = request.data.get(
            "razorpay_signature"
        )

        # 1. Validate request
        if not all([
            razorpay_order_id,
            razorpay_payment_id,
            razorpay_signature
        ]):
            return Response(
                {
                    "status": False,
                    "message": (
                        "razorpay_order_id, "
                        "razorpay_payment_id and "
                        "razorpay_signature are required."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 2. Find order belonging to logged-in user
        try:
            payment_record = CustomerSubscriptionPayment.objects.select_related(
                "plan"
            ).get(
                razorpay_order_id=razorpay_order_id,
                user=request.user
            )

        except CustomerSubscriptionPayment.DoesNotExist:
            return Response(
                {
                    "status": False,
                    "message": "Payment order not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # 3. Prevent duplicate verification
        if payment_record.status == "paid":
            return Response(
                {
                    "status": True,
                    "message": "Payment already verified.",
                    "subscription_active": True
                },
                status=status.HTTP_200_OK
            )

        # 4. Initialize Razorpay
        try:
            client = razorpay.Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET
                )
            )

            # 5. Verify signature
            client.utility.verify_payment_signature({
                "razorpay_order_id": razorpay_order_id,
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_signature": razorpay_signature
            })

            # 6. Fetch payment directly from Razorpay
            razorpay_payment = client.payment.fetch(
                razorpay_payment_id
            )

            # 7. Validate order, amount and currency
            if razorpay_payment.get("order_id") != razorpay_order_id:
                return Response(
                    {
                        "status": False,
                        "message": "Payment order mismatch."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if int(razorpay_payment.get("amount", 0)) != payment_record.amount:
                return Response(
                    {
                        "status": False,
                        "message": "Payment amount mismatch."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if razorpay_payment.get("currency") != payment_record.currency:
                return Response(
                    {
                        "status": False,
                        "message": "Payment currency mismatch."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 8. Activate only captured payments
            if razorpay_payment.get("status") != "captured":
                return Response(
                    {
                        "status": False,
                        "message": (
                            "Payment is not captured yet. "
                            "Subscription is not activated."
                        ),
                        "payment_status": razorpay_payment.get(
                            "status"
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 9. Create subscription atomically
            with transaction.atomic():

                payment_record = (
                    CustomerSubscriptionPayment.objects
                    .select_for_update()
                    .get(id=payment_record.id)
                )

                # Another request may have completed verification
                if payment_record.status == "paid":
                    return Response(
                        {
                            "status": True,
                            "message": "Payment already verified.",
                            "subscription_active": True
                        },
                        status=status.HTTP_200_OK
                    )

                plan = payment_record.plan

                if not plan.is_active:
                    return Response(
                        {
                            "status": False,
                            "message": "Subscription plan is inactive."
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                now = timezone.now()

                # Deactivate previous subscriptions
                CustomerSubscription.objects.filter(
                    user=request.user,
                    is_active=True
                ).update(is_active=False)

                # Create new subscription
                subscription = CustomerSubscription.objects.create(
                    user=request.user,
                    plan=plan,
                    start_date=now,
                    end_date=now + timedelta(
                        days=plan.duration_days
                    ),
                    enquiry_limit=plan.enquiry_limit,
                    enquiry_used=0,
                    is_active=True
                )

                # Mark payment as paid
                payment_record.razorpay_payment_id = (
                    razorpay_payment_id
                )
                payment_record.status = "paid"
                payment_record.save(
                    update_fields=[
                        "razorpay_payment_id",
                        "status",
                        "updated_at"
                    ]
                )

            return Response(
                {
                    "status": True,
                    "message": (
                        "Payment verified and subscription "
                        "activated successfully."
                    ),
                    "payment": {
                        "order_id": razorpay_order_id,
                        "payment_id": razorpay_payment_id,
                        "status": "paid",
                        "amount": payment_record.amount,
                        "currency": payment_record.currency
                    },
                    "subscription": {
                        "id": subscription.id,
                        "plan_id": plan.id,
                        "plan_name": plan.name,
                        "enquiry_limit": subscription.enquiry_limit,
                        "enquiry_used": subscription.enquiry_used,
                        "remaining_enquiries": (
                            subscription.enquiry_limit
                        ),
                        "start_date": subscription.start_date,
                        "end_date": subscription.end_date,
                        "is_active": subscription.is_active
                    }
                },
                status=status.HTTP_200_OK
            )

        except razorpay.errors.SignatureVerificationError:
            return Response(
                {
                    "status": False,
                    "message": "Invalid Razorpay payment signature."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception:
            return Response(
                {
                    "status": False,
                    "message": (
                        "Unable to verify payment. "
                        "Please try again."
                    )
                },
                status=status.HTTP_502_BAD_GATEWAY
            )
        