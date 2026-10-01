from decimal import Decimal

from django.db import transaction
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser

from agreement.models import MarketingPartnerAgreement
from company.utils import send_upi_payout
from .models import Company, CompanyImage, CompanyPayment
from .serializers import CompanySerializer, CompanynameSerializer
from .s3_upload import upload_file_to_s3
from django.core.mail import send_mail
from django.conf import settings
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated
from company.serializers import CompanyListSerializer
from product.models import Product
import json
from decimal import Decimal
from django.db import transaction
from enquiry.models import BankDetails, MarketingPartner
from order.models import OrderItem
from company.shiprocket import create_company_pickup_location

import razorpay

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework_simplejwt.authentication import JWTAuthentication

from django.conf import settings
from django.core.mail import send_mail

# from .models import Company, CompanyImage, MarketingPartner
from .serializers import CompanySerializer
Client = razorpay.Client()
from battery_manegement.firebase import send_fcm_notification

# तुमच्या actual S3 utility चा import
# from company.utils import upload_file_to_s3


class CompanyCreateAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):

        # --------------------------------------------------
        # 1. Validate Company Data
        # --------------------------------------------------

        serializer = CompanySerializer(data=request.data)

        if not serializer.is_valid():
            return Response(
                {
                    "status": False,
                    "message": "Validation failed",
                    "errors": serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # --------------------------------------------------
        # 2. Referral Code
        # --------------------------------------------------

        referral_code = request.data.get("referral_code")
        marketing_partner_name = None

        if referral_code:

            try:
                partner = MarketingPartner.objects.get(
                    referral_code=referral_code
                )

                marketing_partner_name = partner.full_name

            except MarketingPartner.DoesNotExist:

                return Response(
                    {
                        "status": False,
                        "message": "Invalid referral code",
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # --------------------------------------------------
        # 3. Create Company
        # --------------------------------------------------

        company = serializer.save(
            user=request.user,
            referral_code=referral_code,
            marketing_partner_name=marketing_partner_name,
            payment_status="pending",
        )

        # --------------------------------------------------
        # 4. Upload Logo
        # --------------------------------------------------

        logo = request.FILES.get("logo")

        if logo:

            logo_key = upload_file_to_s3(
                logo,
                "company/logo"
            )

            company.logo_s3_key = logo_key
            company.save(update_fields=["logo_s3_key"])

        # --------------------------------------------------
        # 5. Upload Company Images
        # --------------------------------------------------

        images = request.FILES.getlist("images")

        for image in images:

            image_key = upload_file_to_s3(
                image,
                "company/images"
            )

            CompanyImage.objects.create(
                company=company,
                image_s3_key=image_key,
            )

        # --------------------------------------------------
        # 6. Send FCM Notification
        # --------------------------------------------------

        try:

            notification_sent = send_fcm_notification(
                user=request.user,
                title="Company Created Successfully",
                body=f"Your company '{company.name}' has been created successfully.",
                data={
                    "type": "company_created",
                    "company_id": str(company.id),
                    "payment_status": "pending",
                }
            )

        except Exception as e:

            notification_sent = False

            print(
                "FCM Notification Error:",
                str(e)
            )

        # --------------------------------------------------
        # 7. Send Email
        # --------------------------------------------------

        if company.email:

            subject = "Welcome to QNX Mart B2B - Company Admin Panel"

            message = f"""
Dear {company.owner_name or company.name},

Congratulations!

Your company has been registered successfully on QNX Mart B2B.

You can now access your Company Admin Panel using the link below:

https://qnxmartb2b.com/companyadmin/

------------------------------------------------

Company Name : {company.name}
Login Email  : {company.email}

------------------------------------------------

Thank you for choosing QNX Mart B2B.

Regards,
QNX Mart B2B Team
"""

            try:

                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[company.email],
                    fail_silently=False,
                )

            except Exception as e:

                # Email fail झाला तरी company create झालेली आहे
                print(
                    "Email Error:",
                    str(e)
                )

        # --------------------------------------------------
        # 8. Response Serializer
        # --------------------------------------------------

        response_serializer = CompanySerializer(
            company,
            context={
                "request": request
            },
        )

        # --------------------------------------------------
        # 9. Final Response
        # --------------------------------------------------

        return Response(
            {
                "status": True,
                "message": "Company created successfully. Payment pending.",
                "notification_sent": notification_sent,
                "data": response_serializer.data,
            },
            status=status.HTTP_201_CREATED,
        )
from payment.models import PaymentSetting
class CreateCompanyPaymentOrderAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        company_id = request.data.get(
            "company_id"
        )

        try:

            company = Company.objects.get(
                id=company_id
            )

        except Company.DoesNotExist:

            return Response({

                "status": False,

                "message": "Company not found"

            }, status=status.HTTP_404_NOT_FOUND)

        # =========================================
        # GET PAYMENT SETTING
        # =========================================

        payment_setting = (
            PaymentSetting.objects.filter(
                payment_type=(
                    PaymentSetting.COMPANY_REGISTRATION
                ),
                is_active=True
            )
            .first()
        )

        if not payment_setting:

            return Response({

                "status": False,

                "message": (
                    "Company registration amount "
                    "not configured"
                )

            }, status=status.HTTP_404_NOT_FOUND)

        # =========================================
        # RUPEES TO PAISE
        # =========================================

        amount_in_paise = int(
            payment_setting.amount * 100
        )

        client = razorpay.Client(

            auth=(

                settings.RAZORPAY_KEY_ID,

                settings.RAZORPAY_KEY_SECRET

            )

        )

        # =========================================
        # CREATE RAZORPAY ORDER
        # =========================================

        order = client.order.create({

            "amount": amount_in_paise,

            "currency": "INR",

            "payment_capture": 1

        })

        # =========================================
        # SAVE ORDER
        # =========================================

        company.order_id = order["id"]

        company.save(
            update_fields=[
                "order_id"
            ]
        )

        return Response({

            "status": True,

            "order_id": order["id"],

            "amount": str(
                payment_setting.amount
            ),

            "amount_in_paise": (
                amount_in_paise
            ),

            "key": settings.RAZORPAY_KEY_ID,

            "company_id": company.id

        }, status=status.HTTP_200_OK)
        

from .shiprocket import create_company_pickup_location

# class VerifyCompanyPaymentAPIView(APIView):

#     authentication_classes = [JWTAuthentication]
#     permission_classes = [IsAuthenticated]

#     def post(self, request):

#         payment_id = request.data.get("payment_id")
#         order_id = request.data.get("order_id")
#         signature = request.data.get("signature")
#         company_id = request.data.get("company_id")

#         # =====================================================
#         # 1. VALIDATE PAYMENT DATA
#         # =====================================================

#         if not all([
#             payment_id,
#             order_id,
#             signature,
#             company_id
#         ]):

#             return Response(
#                 {
#                     "status": False,
#                     "message": "Missing payment data"
#                 },
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         # =====================================================
#         # 2. RAZORPAY CLIENT
#         # =====================================================

#         client = Client(
#             auth=(
#                 settings.RAZORPAY_KEY_ID,
#                 settings.RAZORPAY_KEY_SECRET
#             )
#         )

#         # =====================================================
#         # 3. VERIFY RAZORPAY SIGNATURE
#         # =====================================================

#         try:

#             client.utility.verify_payment_signature(
#                 {
#                     "razorpay_order_id": order_id,
#                     "razorpay_payment_id": payment_id,
#                     "razorpay_signature": signature
#                 }
#             )

#         except Exception as e:

#             return Response(
#                 {
#                     "status": False,
#                     "message": "Payment verification failed",
#                     "error": str(e)
#                 },
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         # =====================================================
#         # 4. GET COMPANY
#         # =====================================================

#         try:

#             company = Company.objects.get(
#                 id=company_id,
#                 order_id=order_id
#             )

#         except Company.DoesNotExist:

#             return Response(
#                 {
#                     "status": False,
#                     "message": (
#                         "Company not found for this "
#                         "payment order"
#                     )
#                 },
#                 status=status.HTTP_404_NOT_FOUND
#             )

#         # =====================================================
#         # 5. SECURITY CHECK
#         # =====================================================

#         if company.user != request.user:

#             return Response(
#                 {
#                     "status": False,
#                     "message": (
#                         "You do not have permission "
#                         "for this company"
#                     )
#                 },
#                 status=status.HTTP_403_FORBIDDEN
#             )

#         # =====================================================
#         # 6. ALREADY PAID CHECK
#         # =====================================================

#         if company.payment_status == "paid":

#             return Response(
#                 {
#                     "status": True,
#                     "message": "Payment already verified",
#                     "company_id": company.id,
#                     "payment_id": company.payment_id
#                 },
#                 status=status.HTTP_200_OK
#             )

#         # =====================================================
#         # 7. PROCESS PAYMENT
#         # =====================================================

#         try:

#             with transaction.atomic():

#                 # =================================================
#                 # FETCH RAZORPAY ORDER
#                 # =================================================

#                 razorpay_order = client.order.fetch(
#                     order_id
#                 )

#                 # =================================================
#                 # AMOUNT PAISA -> RUPEES
#                 # =================================================

#                 company_amount = (
#                     Decimal(
#                         str(
#                             razorpay_order["amount"]
#                         )
#                     )
#                     / Decimal("100")
#                 )

#                 company_amount = company_amount.quantize(
#                     Decimal("0.01")
#                 )

#                 print(
#                     "========================================"
#                 )

#                 print(
#                     "COMPANY PAYMENT VERIFIED"
#                 )

#                 print(
#                     "COMPANY:",
#                     company.id
#                 )

#                 print(
#                     "AMOUNT:",
#                     company_amount
#                 )

#                 print(
#                     "========================================"
#                 )

#                 # =================================================
#                 # 8. UPDATE COMPANY PAYMENT STATUS
#                 # =================================================

#                 company.payment_id = payment_id
#                 company.payment_status = "paid"

#                 company.save(
#                     update_fields=[
#                         "payment_id",
#                         "payment_status"
#                     ]
#                 )

#                 # =================================================
#                 # 9. SHIPROCKET PICKUP LOCATION
#                 # =================================================

#                 shiprocket_result = None
#                 shiprocket_error = None

#                 try:

#                     shiprocket_result = (
#                         create_company_pickup_location(
#                             company
#                         )
#                     )

#                     print(
#                         "SHIPROCKET PICKUP LOCATION CREATED:"
#                     )

#                     print(
#                         shiprocket_result
#                     )

#                 except Exception as e:

#                     shiprocket_error = str(e)

#                     print(
#                         "SHIPROCKET PICKUP LOCATION "
#                         "CREATION FAILED:"
#                     )

#                     print(
#                         shiprocket_error
#                     )

#                 # =================================================
#                 # 10. FINAL RESPONSE
#                 # =================================================

#                 response_data = {

#                     "status": True,

#                     "message": (
#                         "Payment successful. "
#                         "Company registration completed."
#                     ),

#                     "payment_id": payment_id,

#                     "company_id": company.id,

#                     "company_amount": str(
#                         company_amount
#                     ),

#                     "shiprocket_pickup": (
#                         shiprocket_result
#                         if shiprocket_result
#                         else None
#                     )
#                 }

#                 if shiprocket_error:

#                     response_data[
#                         "shiprocket_error"
#                     ] = shiprocket_error

#                 return Response(
#                     response_data,
#                     status=status.HTTP_200_OK
#                 )

#         # =====================================================
#         # 11. EXCEPTION
#         # =====================================================

#         except Exception as e:

#             import traceback

#             traceback.print_exc()

#             return Response(
#                 {
#                     "status": False,
#                     "message": str(e)
#                 },
#                 status=status.HTTP_400_BAD_REQUEST
#             )
class VerifyCompanyPaymentAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:

            # =====================================================
            # 1. REQUEST DATA
            # =====================================================

            payment_id = request.data.get("payment_id")
            order_id = request.data.get("order_id")
            signature = request.data.get("signature")
            company_id = request.data.get("company_id")

            if not payment_id:
                return Response(
                    {
                        "status": False,
                        "message": "payment_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not order_id:
                return Response(
                    {
                        "status": False,
                        "message": "order_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not signature:
                return Response(
                    {
                        "status": False,
                        "message": "signature is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not company_id:
                return Response(
                    {
                        "status": False,
                        "message": "company_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =====================================================
            # 2. GET COMPANY
            # =====================================================

            try:

                company = Company.objects.get(
                    id=company_id,
                    order_id=order_id
                )

            except Company.DoesNotExist:

                return Response(
                    {
                        "status": False,
                        "message": "Company not found for this payment order",
                        "company_id": company_id,
                        "order_id": order_id
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # =====================================================
            # 3. SECURITY CHECK
            # =====================================================

            if company.user_id != request.user.id:

                return Response(
                    {
                        "status": False,
                        "message": "You do not have permission for this company"
                    },
                    status=status.HTTP_403_FORBIDDEN
                )

            # =====================================================
            # 4. ALREADY PAID
            # =====================================================

            if company.payment_status == "paid":

                return Response(
                    {
                        "status": True,
                        "message": "Payment already verified",
                        "company_id": company.id,
                        "payment_id": company.payment_id,
                        "payment_status": company.payment_status
                    },
                    status=status.HTTP_200_OK
                )

            # =====================================================
            # 5. RAZORPAY CLIENT
            # =====================================================

            client = Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET
                )
            )

            # =====================================================
            # 6. VERIFY RAZORPAY SIGNATURE
            # =====================================================

            try:

                client.utility.verify_payment_signature(
                    {
                        "razorpay_order_id": order_id,
                        "razorpay_payment_id": payment_id,
                        "razorpay_signature": signature
                    }
                )

            except Exception as e:

                return Response(
                    {
                        "status": False,
                        "message": "Payment signature verification failed",
                        "error": str(e)
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =====================================================
            # 7. FETCH RAZORPAY ORDER
            # =====================================================

            try:

                razorpay_order = client.order.fetch(order_id)

            except Exception as e:

                return Response(
                    {
                        "status": False,
                        "message": "Unable to fetch Razorpay order",
                        "error": str(e)
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =====================================================
            # 8. GET RAZORPAY AMOUNT
            # =====================================================

            razorpay_amount = razorpay_order.get("amount")

            if razorpay_amount is None:

                return Response(
                    {
                        "status": False,
                        "message": "Amount not found in Razorpay order"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            company_amount = (
                Decimal(str(razorpay_amount))
                / Decimal("100")
            ).quantize(
                Decimal("0.01")
            )

            # =====================================================
            # 9. UPDATE COMPANY PAYMENT
            # =====================================================

            with transaction.atomic():

                company.payment_id = payment_id
                company.payment_status = "paid"

                company.save(
                    update_fields=[
                        "payment_id",
                        "payment_status"
                    ]
                )

            # =====================================================
            # 10. CREATE SHIPROCKET PICKUP LOCATION
            # =====================================================

            shiprocket_result = None
            shiprocket_error = None

            try:

                shiprocket_result = (
                    create_company_pickup_location(company)
                )

            except Exception as e:

                shiprocket_error = str(e)

            # =====================================================
            # 11. FINAL RESPONSE
            # =====================================================

            response_data = {
                "status": True,
                "message": (
                    "Payment successful. "
                    "Company registration completed."
                ),
                "payment_id": payment_id,
                "company_id": company.id,
                "order_id": order_id,
                "payment_status": company.payment_status,
                "company_amount": str(company_amount),
                "shiprocket_pickup": shiprocket_result
            }

            if shiprocket_error:

                response_data["shiprocket_error"] = shiprocket_error

            return Response(
                response_data,
                status=status.HTTP_200_OK
            )

        # =========================================================
        # GLOBAL EXCEPTION
        # =========================================================

        except Exception as e:

            import traceback

            traceback.print_exc()

            return Response(
                {
                    "status": False,
                    "message": "Something went wrong",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from .models import Company
from rest_framework.permissions import IsAuthenticated
from .serializers import CompanySerializer
from .s3_upload import upload_file_to_s3, delete_file_from_s3

class CompanyUpdateAPIView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
 
    def post(self, request):
        company_id = request.data.get("id")
        if not company_id:
            return Response({
                "status": False,
                "message": "Company ID is required"
            }, status=400)
 
        try:
            company = Company.objects.get(id=company_id)
        except Company.DoesNotExist:
            return Response({
                "status": False,
                "message": "Company not found"
            }, status=404)
 
        if company.user != request.user:
            return Response({
                "status": False,
                "message": "You do not have permission to update this company"
            }, status=403)
 
        serializer = CompanySerializer(company, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({
                "status": False,
                "errors": serializer.errors
            }, status=400)
 
        company = serializer.save()
 
        logo = request.FILES.get("logo")
        if logo:
            if company.logo_s3_key:
                delete_file_from_s3(company.logo_s3_key)
 
            logo_key = upload_file_to_s3(logo, "company/logo")
            company.logo_s3_key = logo_key
            company.save()
 
        delete_ids = request.data.get("delete_image_ids")
        if delete_ids:
            try:
                delete_ids = json.loads(delete_ids)
            except:
                return Response({
                    "status": False,
                    "message": "Invalid delete_image_ids format"
                }, status=400)
 
            images = CompanyImage.objects.filter(
                id__in=delete_ids,
                company=company
            )
 
            for img in images:
                delete_file_from_s3(img.image_s3_key)
                img.delete()
 
        images = request.FILES.getlist("images")
        for image in images:
            image_key = upload_file_to_s3(image, "company/images")
            CompanyImage.objects.create(
                company=company,
                image_s3_key=image_key
            )
 
        # 🔹 Response
        company.refresh_from_db()
        company = Company.objects.prefetch_related("images").get(id=company.id)
 
        response_serializer = CompanySerializer(company, context={"request": request})
 
        return Response({
            "status": True,
            "message": "Company updated successfully",
            "data": response_serializer.data
        }, status=200)



class CompanyListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user

        # If superuser/admin, return all companies
        if user.is_staff:
            companies = Company.objects.all().order_by('-created_at')
        else:
            # Normal users only see their own companies
            companies = Company.objects.filter(user=user).order_by('-created_at')

        serializer = CompanySerializer(companies, many=True)

        return Response({
            "status": True,
            "message": "Companies fetched successfully",
            "data": serializer.data
        }, status=200)
        
class PaidCompanyCountAPIView(APIView):

    def post(self, request):

        count = Company.objects.filter(
            payment_status="paid"
        ).count()

        return Response({
            "status": True,
            "message": "Paid companies count fetched successfully",
            "count": count
        }, status=status.HTTP_200_OK)        

class UnpaidCompanyPendingAmountAPIView(APIView):

    def post(self, request):

        unpaid_count = Company.objects.filter(
            payment_status="pending"
        ).count()

        registration_amount = settings.COMPANY_REGISTRATION_AMOUNT

        total_pending_amount = unpaid_count * registration_amount

        return Response({
            "status": True,
            "message": "Pending company registration amount fetched successfully",
            "unpaid_company_count": unpaid_count,
            "registration_amount": registration_amount,
            "total_pending_amount": total_pending_amount
        }, status=status.HTTP_200_OK)  

class CompanyRetrieveAPIView(APIView):

    def post(self, request):

        company_id = request.data.get("company_id")

        if not company_id:
            return Response({
                "status": False,
                "message": "company_id is required"
            }, status=400)

        try:
            company = Company.objects.prefetch_related("images").get(id=company_id)

        except Company.DoesNotExist:
            return Response({
                "status": False,
                "message": "Company not found"
            }, status=404)

        serializer = CompanySerializer(
            company,
            context={"request": request}
        )

        return Response({
            "status": True,
            "message": "Company fetched successfully",
            "data": serializer.data
        }, status=200)
        
class CompanycountListAPIView(APIView):

    def post(self, request):

        # Without login, return all companies
        companies = Company.objects.all()

        serializer = CompanySerializer(companies, many=True)

        return Response({
            "status": True,
            "message": "Companies fetched successfully",
            "total": companies.count(),
            # "data": serializer.data
        }, status=200)
        
class UserCompanycountListAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        # 🔹 Get only logged-in user's companies
        companies = Company.objects.filter(user=request.user, is_active=True)

        serializer = CompanySerializer(companies, many=True)

        return Response({
            "status": True,
            "message": "User companies fetched successfully",
            "total": companies.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)        

class CompanyallListAPIView(APIView):

    def post(self, request):

        companies = Company.objects.all()

        serializer = CompanySerializer(companies, many=True)

        return Response({
            "status": True,
            "message": "Companies fetched successfully",
            "data": serializer.data
        }, status=200)


class CompanynameListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user

        # Admin / Staff
        if user.is_staff:
            companies = Company.objects.filter(
                is_active=True,
                payment_status="paid"
            ).order_by('-created_at')

        # Normal User
        else:
            companies = Company.objects.filter(
                user=user,
                is_active=True,
                payment_status="paid"
            ).order_by('-created_at')

        serializer = CompanynameSerializer(companies, many=True)

        return Response({
            "status": True,
            "message": "Active companies fetched successfully",
            "data": serializer.data
        }, status=200)


# Soft Delete CompanyAPIView
class SoftDeleteCompanyAPIView(APIView):
    def post(self, request):
        company_id = request.data.get("company_id")
        try:
            company = Company.objects.get(
                id=company_id,
                is_active=True
            )
        except Company.DoesNotExist:
            return Response(
                {"error": "Company not found or already deleted"},
                status=404
            )
        company.is_active = False
        company.save()
        return Response({"message": "Company soft deleted successfully"})


# Restore CompanyAPIView
class RestoreCompanyAPIView(APIView):
    def post(self, request):
        company_id = request.data.get("company_id")
        try:
            company = Company.objects.get(
                id=company_id,
                is_active=False
            )
        except Company.DoesNotExist:
            return Response(
                {"error": "Company not found or already active"},
                status=404
            )
        company.is_active = True
        company.save()
        return Response({"message": "Company restored successfully"})
    




class FirstFiveCompaniesAPIView(APIView):

    def post(self, request):

        companies = Company.objects.order_by('-id')[:5]

        serializer = CompanyListSerializer(companies, many=True)

        return Response({
            "status": True,
            "message": "Latest 5 companies fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)    
    


class OwnerNameListView(APIView):

    def post(self, request):

        owners = Company.objects.all() \
                                .exclude(owner_name__isnull=True) \
                                .exclude(owner_name="") \
                                .values_list('owner_name', flat=True)

        return Response({
            "status": "success",
            "data": list(owners)
        })
    





class CompanyProductListView(APIView):

    def post(self, request):

        company_id = request.data.get('company_id')

        if not company_id:
            return Response({
                "status": "error",
                "message": "company_id is required"
            }, status=400)

        products = Product.objects.filter(company_id=company_id)

        data = products.values(
            'id',
            'thumbnail_s3_key',
            'name',
            'price',
            'final_price',
            'stock_quantity',
            'status'
        )

        return Response({
            "status": "success",
            "data": list(data)
        })    
        
        
        
from django.db.models import Sum, F
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

class CompanyStockAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        company = request.user.companies.first()

        if not company:
            return Response({
                "status": False,
                "message": "Company not found"
            }, status=404)

        products = Product.objects.filter(company=company)

        result = []

        for product in products:

            sold_qty = OrderItem.objects.filter(
                product=product,
                order__company=company
            ).aggregate(total=Sum("quantity"))["total"] or 0

            remaining_stock = product.stock_quantity - sold_qty

            result.append({
                "product_id": product.id,
                "product_name": product.name,
                "stock_quantity": product.stock_quantity,
                "sold_quantity": sold_qty,
                "remaining_stock": max(0, remaining_stock),
                "company_name": company.name
            })

        return Response({
            "status": True,
            "company": company.name,
            "products": result
        })        
        
class LowStockProductsAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        company = request.user.companies.first()

        if not company:
            return Response({
                "status": False,
                "message": "Company not found"
            }, status=404)

        products = Product.objects.filter(
            company=company,
            stock_quantity__lte=10
        ).values(
            "id",
            "name",
            "stock_quantity",
            "thumbnail_s3_key",
            "price",
            "final_price"
        )

        return Response({
            "status": True,
            "message": "Low stock products",
            "count": products.count(),
            "products": list(products)
        })    
            



from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import suppliers
from .serializers import SupplierSerializer

class SupplierCreateAPIView(APIView):
    def post(self, request):
        serializer = SupplierSerializer(data=request.data)

        if serializer.is_valid():
            supplier = serializer.save()
            return Response({
                "msg": "Supplier created successfully",
                "status": "success",
                "data": SupplierSerializer(supplier).data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "msg": "Validation error",
            "status": "error",
            "data": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)   
        
        
             
        
class SupplierUpdateAPIView(APIView):

    def post(self, request):
        supplier_id = request.data.get('id')

        if not supplier_id:
            return Response({
                "msg": "ID is required",
                "status": "error",
                "data": {}
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            instance = suppliers.objects.get(id=supplier_id)
        except suppliers.DoesNotExist:
            return Response({
                "msg": "Supplier not found",
                "status": "error",
                "data": {}
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = SupplierSerializer(instance, data=request.data, partial=True)

        if serializer.is_valid():
            serializer.save()
            return Response({
                "msg": "Supplier updated successfully",
                "status": "success",
                "data": serializer.data
            }, status=status.HTTP_200_OK)

        return Response({
            "msg": "Validation error",
            "status": "error",
            "data": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

class SupplierDeleteAPIView(APIView):

    def post(self, request):
        supplier_id = request.data.get('id')

        if not supplier_id:
            return Response({
                "msg": "ID is required",
                "status": "error",
                "data": {}
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            instance = suppliers.objects.get(id=supplier_id)
        except suppliers.DoesNotExist:
            return Response({
                "msg": "Supplier not found",
                "status": "error",
                "data": {}
            }, status=status.HTTP_404_NOT_FOUND)

        instance.delete()

        return Response({
            "msg": "Supplier deleted successfully",
            "status": "success",
            "data": {}
        }, status=status.HTTP_200_OK)  
              
        
class SupplierListAPIView(APIView):

    def post(self, request):
        company_id = request.data.get("company")

        if not company_id:
            return Response({
                "msg": "Company ID is required",
                "status": "error",
                "data": []
            }, status=status.HTTP_400_BAD_REQUEST)

        queryset = suppliers.objects.filter(company_id=company_id).order_by('-id')
        serializer = SupplierSerializer(queryset, many=True)

        return Response({
            "msg": "Suppliers retrieved successfully",
            "status": "success",
            "data": serializer.data
        }, status=status.HTTP_200_OK)