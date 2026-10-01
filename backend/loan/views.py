from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from firebase_admin import messaging

from accounts.models import FCMToken
from .serializers import LoanEnquirySerializer


class LoanEnquiryCreateAPIView(APIView):

    def post(self, request):

        # ==========================================
        # 1. Validate Loan Enquiry
        # ==========================================

        serializer = LoanEnquirySerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                {
                    "success": False,
                    "message": "Validation failed.",
                    "errors": serializer.errors
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==========================================
        # 2. Save Loan Enquiry
        # ==========================================

        enquiry = serializer.save()

        # ==========================================
        # 3. Get Admin FCM Tokens
        # ==========================================

        admin_tokens = list(
            FCMToken.objects.filter(
                user__role__role_name__iexact="admin",
                is_active=True
            ).values_list(
                "token",
                flat=True
            )
        )

        notification_response = []

        # ==========================================
        # 4. Send Notification To Admin Panel
        # ==========================================

        for token in admin_tokens:

            try:

                message = messaging.Message(

                    notification=messaging.Notification(
                        title="New Loan Enquiry",
                        body=(
                            f"New loan enquiry received "
                            f"from {enquiry.name}"
                        )
                    ),

                    data={
                        "type": "loan_enquiry",
                        "action": "open_loan_enquiry",
                        "enquiry_id": str(enquiry.id)
                    },

                    token=token
                )

                firebase_response = messaging.send(message)

                notification_response.append({
                    "success": True,
                    "message_id": firebase_response
                })

            except Exception as e:

                notification_response.append({
                    "success": False,
                    "error": str(e)
                })

        # ==========================================
        # 5. Notification Status
        # ==========================================

        notification_sent = any(
            item["success"]
            for item in notification_response
        )

        # ==========================================
        # 6. Final Response
        # ==========================================

        return Response(
            {
                "success": True,

                "message":
                    "Loan enquiry submitted successfully.",

                "enquiry_id":
                    enquiry.id,

                "notification": {
                    "sent":
                        notification_sent,

                    "admin_count":
                        len(admin_tokens),

                    "response":
                        notification_response
                },

                "data":
                    serializer.data
            },

            status=status.HTTP_201_CREATED
        )



from loan.models import LoanEnquiry        
class LoanEnquiryListAPIView(APIView):

    def post(self, request):

        queryset = LoanEnquiry.objects.all().order_by("-created_at")

        # ==========================================
        # FILTER BY STATUS
        # ==========================================

        enquiry_status = request.data.get("status")

        if enquiry_status:
            queryset = queryset.filter(
                status=enquiry_status
            )

        # ==========================================
        # FILTER BY LOAN TYPE
        # ==========================================

        loan_type = request.data.get("loan_type")

        if loan_type:
            queryset = queryset.filter(
                loan_type=loan_type
            )

        # ==========================================
        # FILTER BY MOBILE
        # ==========================================

        mobile = request.GET.get("mobile")

        if mobile:
            queryset = queryset.filter(
                mobile__icontains=mobile
            )

        # ==========================================
        # FILTER BY CITY
        # ==========================================

        city = request.GET.get("city")

        if city:
            queryset = queryset.filter(
                city__icontains=city
            )

        # ==========================================
        # FILTER BY EMPLOYMENT TYPE
        # ==========================================

        employment_type = request.GET.get(
            "employment_type"
        )

        if employment_type:
            queryset = queryset.filter(
                employment_type=employment_type
            )

        # ==========================================
        # SERIALIZER
        # ==========================================

        serializer = LoanEnquirySerializer(
            queryset,
            many=True
        )

        return Response({

            "success": True,

            "message":
                "Loan enquiries fetched successfully.",

            "count":
                queryset.count(),

            "data":
                serializer.data

        }, status=status.HTTP_200_OK)        