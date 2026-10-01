from decimal import Decimal
from django.core.mail import message
import razorpay
from django.utils import timezone
from datetime import timedelta
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
import urllib
from .models import PaymentSetting, PropertySubscriptionPlan, PropertySubscriptionPayment
from real_estate.models import Property
from django.db import transaction
from rest_framework.permissions import IsAuthenticated

client = razorpay.Client(
    auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
)

from decimal import Decimal, InvalidOperation
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import PaymentSetting


class CreatePaymentSettingAPIView(APIView):

    def post(self, request):

        payment_type = request.data.get(
            "payment_type"
        )

        amount = request.data.get(
            "amount"
        )

        # =========================================
        # VALIDATION
        # =========================================

        if not payment_type or amount is None:

            return Response(
                {
                    "status": False,
                    "message": (
                        "payment_type and amount "
                        "are required"
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =========================================
        # AMOUNT VALIDATION
        # =========================================

        try:

            amount = Decimal(
                str(amount)
            )

        except (InvalidOperation, ValueError):

            return Response(
                {
                    "status": False,
                    "message": "Invalid amount"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if amount <= 0:

            return Response(
                {
                    "status": False,
                    "message": (
                        "Amount must be greater than 0"
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =========================================
        # DUPLICATE CHECK
        # =========================================

        if PaymentSetting.objects.filter(
            payment_type=payment_type
        ).exists():

            return Response(
                {
                    "status": False,
                    "message": (
                        "Payment setting already exists"
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =========================================
        # CREATE
        # =========================================

        payment_setting = (
            PaymentSetting.objects.create(

                payment_type=payment_type,

                amount=amount

            )
        )

        return Response(
            {
                "status": True,

                "message": (
                    "Payment setting created successfully"
                ),

                "data": {

                    "id": payment_setting.id,

                    "payment_type": (
                        payment_setting.payment_type
                    ),

                    "amount": str(
                        payment_setting.amount
                    ),

                    "is_active": (
                        payment_setting.is_active
                    )

                }
            },
            status=status.HTTP_201_CREATED
        )
        
class UpdateCompanyRegistrationAmountAPIView(APIView):

    def post(self, request):

        amount = request.data.get("amount")

        # =========================================
        # VALIDATION
        # =========================================

        if amount is None:

            return Response(
                {
                    "status": False,
                    "message": "Amount is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            amount = Decimal(
                str(amount)
            )

        except (InvalidOperation, ValueError):

            return Response(
                {
                    "status": False,
                    "message": "Invalid amount"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if amount <= 0:

            return Response(
                {
                    "status": False,
                    "message": (
                        "Amount must be greater than 0"
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =========================================
        # GET OR CREATE AMOUNT
        # =========================================

        payment_amount = (
            PaymentSetting.objects
            .first()
        )

        if not payment_amount:

            payment_amount = (
                PaymentSetting.objects.create(
                    payment_type=PaymentSetting.COMPANY_REGISTRATION,
                    amount=amount
                )
            )

        else:

            payment_amount.amount = amount

            payment_amount.save(
                update_fields=[
                    "amount",
                    "updated_at"
                ]
            )

        # =========================================
        # RESPONSE
        # =========================================

        return Response(
            {
                "status": True,
                "message": (
                    "Company registration amount "
                    "updated successfully"
                ),
                "data": {
                    "id": payment_amount.id,
                    "amount": str(
                        payment_amount.amount
                    )
                }
            },
            status=status.HTTP_200_OK
        )
                

    
        
        
        
        
        
        
import razorpay

from django.conf import settings
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from shiprocket.models import ShipOrder
from payment.models import RazorpayPayment


class CreateRazorpayOrderAPIView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        ship_order_id = request.data.get("ship_order_id")

        if not ship_order_id:
            return Response({
                "success": False,
                "message": "ship_order_id is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get ShipOrder
        try:
            ship_order = ShipOrder.objects.get(
                id=ship_order_id
            )
        except ShipOrder.DoesNotExist:
            return Response({
                "success": False,
                "message": "ShipOrder not found."
            }, status=status.HTTP_404_NOT_FOUND)

        # Check existing Razorpay payment
        try:
            payment = ship_order.razorpay_payment
        except RazorpayPayment.DoesNotExist:
            payment = None

        # Already successful
        if payment and payment.status == "success":
            return Response({
                "success": False,
                "message": "Payment already completed.",
                "data": {
                    "ship_order_id": ship_order.id,
                    "razorpay_order_id": payment.razorpay_order_id,
                    "status": payment.status
                }
            }, status=status.HTTP_400_BAD_REQUEST)

        # Amount
        amount = ship_order.total_amount

        if not amount or amount <= 0:
            return Response({
                "success": False,
                "message": "Invalid order amount."
            }, status=status.HTTP_400_BAD_REQUEST)

        # Razorpay client
        client = razorpay.Client(
            auth=(
                settings.RAZORPAY_KEY_ID,
                settings.RAZORPAY_KEY_SECRET
            )
        )

        # Amount in paise
        amount_in_paise = int(
            float(amount) * 100
        )

        # Create Razorpay order
        razorpay_order = client.order.create({
            "amount": amount_in_paise,
            "currency": "INR",
            "receipt": str(ship_order.order_number),
            "notes": {
                "ship_order_id": str(ship_order.id),
                "order_number": str(ship_order.order_number),
            }
        })

        # Create / update local payment record
        if payment:

            payment.razorpay_order_id = razorpay_order["id"]
            payment.amount = amount
            payment.currency = "INR"
            payment.status = "created"
            payment.error_code = None
            payment.error_description = None
            payment.save()

        else:

            payment = RazorpayPayment.objects.create(
                order=ship_order,
                razorpay_order_id=razorpay_order["id"],
                amount=amount,
                currency="INR",
                status="created"
            )

        return Response({
            "success": True,
            "message": "Razorpay Order Created Successfully.",
            "data": {
                "ship_order_id": ship_order.id,
                "order_number": ship_order.order_number,

                "razorpay_order_id": razorpay_order["id"],

                "amount": amount_in_paise,

                "amount_rupees": float(amount),

                "currency": "INR",

                "key_id": settings.RAZORPAY_KEY_ID,

                "status": payment.status
            }
        }, status=status.HTTP_201_CREATED)
        
        
# class VerifyRazorpayPaymentAPIView(APIView):

#     permission_classes = [IsAuthenticated]

#     def post(self, request):

#         ship_order_id = request.data.get("ship_order_id")
#         razorpay_order_id = request.data.get("razorpay_order_id")
#         razorpay_payment_id = request.data.get("razorpay_payment_id")
#         razorpay_signature = request.data.get("razorpay_signature")

#         # Required fields
#         if not all([
#             ship_order_id,
#             razorpay_order_id,
#             razorpay_payment_id,
#             razorpay_signature
#         ]):
#             return Response({
#                 "success": False,
#                 "message": "ship_order_id, razorpay_order_id, "
#                            "razorpay_payment_id and razorpay_signature are required."
#             }, status=status.HTTP_400_BAD_REQUEST)

#         # Get ShipOrder
#         try:
#             ship_order = ShipOrder.objects.get(
#                 id=ship_order_id
#             )
#         except ShipOrder.DoesNotExist:
#             return Response({
#                 "success": False,
#                 "message": "ShipOrder not found."
#             }, status=status.HTTP_404_NOT_FOUND)

#         # Get Razorpay payment record
#         try:
#             payment = RazorpayPayment.objects.get(
#                 order=ship_order
#             )
#         except RazorpayPayment.DoesNotExist:
#             return Response({
#                 "success": False,
#                 "message": "Razorpay payment record not found."
#             }, status=status.HTTP_404_NOT_FOUND)

#         # Check Razorpay Order ID
#         if payment.razorpay_order_id != razorpay_order_id:
#             return Response({
#                 "success": False,
#                 "message": "Invalid Razorpay Order ID."
#             }, status=status.HTTP_400_BAD_REQUEST)

#         # Razorpay client
#         client = razorpay.Client(
#             auth=(
#                 settings.RAZORPAY_KEY_ID,
#                 settings.RAZORPAY_KEY_SECRET
#             )
#         )

#         # Verify signature
#         try:

#             client.utility.verify_payment_signature({
#                 "razorpay_order_id": razorpay_order_id,
#                 "razorpay_payment_id": razorpay_payment_id,
#                 "razorpay_signature": razorpay_signature
#             })

#         except razorpay.errors.SignatureVerificationError:

#             payment.status = "failed"
#             payment.error_code = "SIGNATURE_VERIFICATION_FAILED"
#             payment.error_description = "Razorpay signature verification failed."
#             payment.save()

#             return Response({
#                 "success": False,
#                 "message": "Payment verification failed."
#             }, status=status.HTTP_400_BAD_REQUEST)

#         # Payment successful
#         payment.razorpay_payment_id = razorpay_payment_id
#         payment.razorpay_signature = razorpay_signature
#         payment.status = "success"

#         # Get actual payment method from Razorpay
#         try:
#             payment_details = client.payment.fetch(
#                 razorpay_payment_id
#             )

#             payment.payment_method = payment_details.get(
#                 "method"
#             )

#         except Exception:
#             pass

#         payment.save()

#         return Response({
#             "success": True,
#             "message": "Payment Verified Successfully.",
#             "data": {
#                 "ship_order_id": ship_order.id,
#                 "order_number": ship_order.order_number,
#                 "razorpay_order_id": payment.razorpay_order_id,
#                 "razorpay_payment_id": payment.razorpay_payment_id,
#                 "amount": float(payment.amount),
#                 "currency": payment.currency,
#                 "payment_method": payment.payment_method,
#                 "status": payment.status
#             }
#         }, status=status.HTTP_200_OK)        
class VerifyRazorpayPaymentAPIView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        ship_order_id = request.data.get("ship_order_id")
        razorpay_order_id = request.data.get("razorpay_order_id")
        razorpay_payment_id = request.data.get("razorpay_payment_id")
        razorpay_signature = request.data.get("razorpay_signature")

        # ==========================================
        # REQUIRED FIELDS
        # ==========================================

        if not all([
            ship_order_id,
            razorpay_order_id,
            razorpay_payment_id,
            razorpay_signature
        ]):
            return Response({
                "success": False,
                "message": (
                    "ship_order_id, razorpay_order_id, "
                    "razorpay_payment_id and razorpay_signature "
                    "are required."
                )
            }, status=status.HTTP_400_BAD_REQUEST)

        # ==========================================
        # GET SHIP ORDER
        # ==========================================

        try:
            ship_order = ShipOrder.objects.get(
                id=ship_order_id
            )

        except ShipOrder.DoesNotExist:

            return Response({
                "success": False,
                "message": "ShipOrder not found."
            }, status=status.HTTP_404_NOT_FOUND)

        # ==========================================
        # SECURITY:
        # CHECK ORDER BELONGS TO LOGGED-IN USER
        # ==========================================

        if ship_order.user_id != request.user.id:

            return Response({
                "success": False,
                "message": "You are not authorized to verify this order."
            }, status=status.HTTP_403_FORBIDDEN)

        # ==========================================
        # GET RAZORPAY PAYMENT RECORD
        # ==========================================

        try:
            payment = RazorpayPayment.objects.get(
                order=ship_order
            )

        except RazorpayPayment.DoesNotExist:

            return Response({
                "success": False,
                "message": "Razorpay payment record not found."
            }, status=status.HTTP_404_NOT_FOUND)

        # ==========================================
        # CHECK RAZORPAY ORDER ID
        # ==========================================

        if payment.razorpay_order_id != razorpay_order_id:

            return Response({
                "success": False,
                "message": "Invalid Razorpay Order ID."
            }, status=status.HTTP_400_BAD_REQUEST)

        # ==========================================
        # ALREADY SUCCESSFUL PAYMENT
        # ==========================================

        if (
            payment.status == "success"
            and payment.razorpay_payment_id == razorpay_payment_id
        ):

            # Make sure ShipOrder is also marked paid
            if not ship_order.payment_status:

                ship_order.payment_status = True
                ship_order.save(
                    update_fields=[
                        "payment_status",
                        "updated_at"
                    ]
                )

            return Response({
                "success": True,
                "message": "Payment already verified.",
                "data": {
                    "ship_order_id": ship_order.id,
                    "order_number": ship_order.order_number,
                    "razorpay_order_id": payment.razorpay_order_id,
                    "razorpay_payment_id": payment.razorpay_payment_id,
                    "amount": float(payment.amount),
                    "currency": payment.currency,
                    "payment_method": payment.payment_method,
                    "payment_status": ship_order.payment_status,
                    "status": payment.status
                }
            }, status=status.HTTP_200_OK)

        # ==========================================
        # RAZORPAY CLIENT
        # ==========================================

        client = razorpay.Client(
            auth=(
                settings.RAZORPAY_KEY_ID,
                settings.RAZORPAY_KEY_SECRET
            )
        )

        # ==========================================
        # VERIFY RAZORPAY SIGNATURE
        # ==========================================

        try:

            client.utility.verify_payment_signature({
                "razorpay_order_id": razorpay_order_id,
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_signature": razorpay_signature
            })

        except razorpay.errors.SignatureVerificationError:

            payment.status = "failed"
            payment.error_code = "SIGNATURE_VERIFICATION_FAILED"
            payment.error_description = (
                "Razorpay signature verification failed."
            )

            payment.save()

            return Response({
                "success": False,
                "message": "Payment verification failed."
            }, status=status.HTTP_400_BAD_REQUEST)

        # ==========================================
        # FETCH PAYMENT DETAILS FROM RAZORPAY
        # ==========================================

        payment_method = None

        try:

            payment_details = client.payment.fetch(
                razorpay_payment_id
            )

            payment_method = payment_details.get("method")

        except Exception:

            payment_method = None

        # ==========================================
        # UPDATE RAZORPAY PAYMENT
        # ==========================================

        payment.razorpay_payment_id = razorpay_payment_id
        payment.razorpay_signature = razorpay_signature
        payment.status = "success"

        if payment_method:
            payment.payment_method = payment_method

        payment.error_code = None
        payment.error_description = None

        payment.save()

        # ==========================================
        # IMPORTANT:
        # UPDATE SHIP ORDER PAYMENT STATUS
        # ==========================================

        ship_order.payment_status = True

        # Optional:
        # जर PREPAID payment असेल तर order status CONFIRMED करा
        if ship_order.payment_method == "PREPAID":
            ship_order.status = "CONFIRMED"

            ship_order.save(
                update_fields=[
                    "payment_status",
                    "status",
                    "updated_at"
                ]
            )

        else:

            ship_order.save(
                update_fields=[
                    "payment_status",
                    "updated_at"
                ]
            )

        # ==========================================
        # SUCCESS RESPONSE
        # ==========================================

        return Response({
            "success": True,
            "message": "Payment Verified Successfully.",
            "data": {
                "ship_order_id": ship_order.id,
                "order_number": ship_order.order_number,

                "razorpay_order_id": (
                    payment.razorpay_order_id
                ),

                "razorpay_payment_id": (
                    payment.razorpay_payment_id
                ),

                "amount": float(payment.amount),

                "currency": payment.currency,

                "payment_method": (
                    payment.payment_method
                ),

                "payment_status": (
                    ship_order.payment_status
                ),

                "order_status": (
                    ship_order.status
                ),

                "status": payment.status
            }
        }, status=status.HTTP_200_OK)
        
        
class PropertySubscriptionCreateOrderAPIView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:

            property_id = request.data.get("property_id")
            plan_id = request.data.get("plan_id")

            if not property_id:
                return Response(
                    {
                        "success": False,
                        "message": "property_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not plan_id:
                return Response(
                    {
                        "success": False,
                        "message": "plan_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                property_obj = Property.objects.get(
                    id=property_id
                )
            except Property.DoesNotExist:
                return Response(
                    {
                        "success": False,
                        "message": "Property not found"
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            try:
                plan = PropertySubscriptionPlan.objects.get(
                    id=plan_id,
                    is_active=True
                )
            except PropertySubscriptionPlan.DoesNotExist:
                return Response(
                    {
                        "success": False,
                        "message": "Subscription plan not found"
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # Admin properties do not need subscription
            if property_obj.source == "admin":

                return Response(
                    {
                        "success": False,
                        "message": "Admin created property does not require subscription"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Already active
            if property_obj.subscription_active:

                return Response(
                    {
                        "success": False,
                        "message": "Subscription is already active"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            razorpay_client = razorpay.Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET
                )
            )

            amount = int(
                plan.price * 100
            )

            razorpay_order = razorpay_client.order.create(
                data={
                    "amount": amount,
                    "currency": "INR",
                    "receipt": f"property_{property_obj.id}_plan_{plan.id}",
                    "notes": {
                        "property_id": str(property_obj.id),
                        "plan_id": str(plan.id),
                        "user_id": str(request.user.id)
                    }
                }
            )

            payment = PropertySubscriptionPayment.objects.create(
                property=property_obj,
                plan=plan,
                user=request.user,
                amount=plan.price,
                razorpay_order_id=razorpay_order["id"],
                status="created"
            )

            return Response(
                {
                    "success": True,
                    "message": "Razorpay order created successfully",

                    "data": {
                        "payment_id": payment.id,

                        "property_id": property_obj.id,

                        "plan_id": plan.id,
                        "plan_name": plan.name,
                        "days": plan.days,
                        "amount": plan.price,

                        "razorpay_order_id": razorpay_order["id"],

                        "razorpay_key": settings.RAZORPAY_KEY_ID,

                        "currency": "INR"
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to create Razorpay order",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )        
            
            
            
class PropertySubscriptionVerifyAPIView(APIView):

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):

        try:

            razorpay_order_id = request.data.get(
                "razorpay_order_id"
            )

            razorpay_payment_id = request.data.get(
                "razorpay_payment_id"
            )

            razorpay_signature = request.data.get(
                "razorpay_signature"
            )

            if not razorpay_order_id:
                return Response(
                    {
                        "success": False,
                        "message": "razorpay_order_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not razorpay_payment_id:
                return Response(
                    {
                        "success": False,
                        "message": "razorpay_payment_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not razorpay_signature:
                return Response(
                    {
                        "success": False,
                        "message": "razorpay_signature is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:

                payment = PropertySubscriptionPayment.objects.select_for_update().get(
                    razorpay_order_id=razorpay_order_id,
                    user=request.user
                )

            except PropertySubscriptionPayment.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Payment order not found"
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # Prevent duplicate verification
            if payment.status == "paid":

                return Response(
                    {
                        "success": True,
                        "message": "Payment already verified",
                        "data": {
                            "property_id": payment.property.id,
                            "subscription_active": payment.property.subscription_active
                        }
                    },
                    status=status.HTTP_200_OK
                )

            razorpay_client = razorpay.Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET
                )
            )

            # Verify Razorpay signature
            razorpay_client.utility.verify_payment_signature(
                {
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_signature": razorpay_signature
                }
            )

            property_obj = payment.property
            plan = payment.plan

            # Update payment
            payment.razorpay_payment_id = razorpay_payment_id
            payment.status = "paid"
            payment.paid_at = timezone.now()
            payment.save(
                update_fields=[
                    "razorpay_payment_id",
                    "status",
                    "paid_at"
                ]
            )

            # Activate subscription
            now = timezone.now()

            property_obj.subscription_active = True
            property_obj.subscription_required = False

            # Subscription expiry
            property_obj.expiry_date = now + timedelta(
                days=plan.days
            )

            property_obj.save(
                update_fields=[
                    "subscription_active",
                    "subscription_required",
                    "expiry_date",
                    "updated_at"
                ]
            )

            return Response(
                {
                    "success": True,
                    "message": "Subscription activated successfully",

                    "data": {
                        "property_id": property_obj.id,

                        "plan": {
                            "id": plan.id,
                            "name": plan.name,
                            "days": plan.days,
                            "amount": plan.price
                        },

                        "razorpay_payment_id": razorpay_payment_id,
                        "razorpay_order_id": razorpay_order_id,

                        "subscription_active": True,
                        "subscription_required": False,

                        "subscription_expiry_date": property_obj.expiry_date
                    }
                },
                status=status.HTTP_200_OK
            )

        except razorpay.errors.SignatureVerificationError:

            return Response(
                {
                    "success": False,
                    "message": "Invalid Razorpay payment signature"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Payment verification failed",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
            
class PropertySubscriptionPlanCreateAPIView(APIView):

    def post(self, request):

        try:
            name = request.data.get("name")
            days = request.data.get("days")
            price = request.data.get("price")

            # Required fields
            if not name:
                return Response(
                    {
                        "success": False,
                        "message": "Plan name is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if days is None:
                return Response(
                    {
                        "success": False,
                        "message": "days is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if price is None:
                return Response(
                    {
                        "success": False,
                        "message": "price is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Validate days
            try:
                days = int(days)
            except (ValueError, TypeError):
                return Response(
                    {
                        "success": False,
                        "message": "days must be a valid number"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if days <= 0:
                return Response(
                    {
                        "success": False,
                        "message": "days must be greater than 0"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Validate price
            try:
                price = float(price)
            except (ValueError, TypeError):
                return Response(
                    {
                        "success": False,
                        "message": "price must be a valid number"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if price <= 0:
                return Response(
                    {
                        "success": False,
                        "message": "price must be greater than 0"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Check duplicate active plan
            if PropertySubscriptionPlan.objects.filter(
                name__iexact=name.strip(),
                is_active=True
            ).exists():

                return Response(
                    {
                        "success": False,
                        "message": "An active plan with this name already exists"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Create plan
            plan = PropertySubscriptionPlan.objects.create(
                name=name.strip(),
                days=days,
                price=price,
                is_active=True
            )

            return Response(
                {
                    "success": True,
                    "message": "Property subscription plan created successfully",
                    "data": {
                        "id": plan.id,
                        "name": plan.name,
                        "days": plan.days,
                        "price": plan.price,
                        "is_active": plan.is_active,
                        "created_at": plan.created_at,
                        "updated_at": plan.updated_at
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to create property subscription plan",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
            
class PropertySubscriptionPlanListAPIView(APIView):

    def post(self, request):

        try:
            plans = PropertySubscriptionPlan.objects.filter(
                is_active=True
            ).order_by("days", "price")

            data = []

            for plan in plans:
                data.append(
                    {
                        "id": plan.id,
                        "name": plan.name,
                        "days": plan.days,
                        "price": plan.price,
                        "is_active": plan.is_active,
                        "created_at": plan.created_at,
                        "updated_at": plan.updated_at
                    }
                )

            return Response(
                {
                    "success": True,
                    "message": "Property subscription plans fetched successfully",
                    "count": plans.count(),
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to fetch property subscription plans",
                    "error": str(e),
                    "data": []
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
            
class PropertySubscriptionPlanUpdateAPIView(APIView):

    def post(self, request):

        try:
            plan_id = request.data.get("id")

            if not plan_id:
                return Response(
                    {
                        "success": False,
                        "message": "Plan id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                plan = PropertySubscriptionPlan.objects.get(
                    id=plan_id
                )
            except PropertySubscriptionPlan.DoesNotExist:
                return Response(
                    {
                        "success": False,
                        "message": "Subscription plan not found"
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # Get request values
            name = request.data.get("name")
            days = request.data.get("days")
            price = request.data.get("price")
            is_active = request.data.get("is_active")

            # Update name
            if name is not None:

                name = str(name).strip()

                if not name:
                    return Response(
                        {
                            "success": False,
                            "message": "Plan name cannot be empty"
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                # Duplicate name check
                if PropertySubscriptionPlan.objects.filter(
                    name__iexact=name,
                    is_active=True
                ).exclude(
                    id=plan.id
                ).exists():

                    return Response(
                        {
                            "success": False,
                            "message": "An active plan with this name already exists"
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                plan.name = name

            # Update days
            if days is not None:

                try:
                    days = int(days)
                except (ValueError, TypeError):

                    return Response(
                        {
                            "success": False,
                            "message": "days must be a valid number"
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                if days <= 0:
                    return Response(
                        {
                            "success": False,
                            "message": "days must be greater than 0"
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                plan.days = days

            # Update price
            if price is not None:

                try:
                    price = float(price)
                except (ValueError, TypeError):

                    return Response(
                        {
                            "success": False,
                            "message": "price must be a valid number"
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                if price <= 0:
                    return Response(
                        {
                            "success": False,
                            "message": "price must be greater than 0"
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                plan.price = price

            # Update active status
            if is_active is not None:

                if isinstance(is_active, str):
                    is_active = is_active.lower() in [
                        "true",
                        "1",
                        "yes"
                    ]

                plan.is_active = bool(is_active)

            plan.save()

            return Response(
                {
                    "success": True,
                    "message": "Property subscription plan updated successfully",
                    "data": {
                        "id": plan.id,
                        "name": plan.name,
                        "days": plan.days,
                        "price": plan.price,
                        "is_active": plan.is_active,
                        "created_at": plan.created_at,
                        "updated_at": plan.updated_at
                    }
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to update property subscription plan",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )      
            
                  