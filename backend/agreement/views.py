
import json
import traceback

from django.db import transaction
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework_simplejwt.authentication import JWTAuthentication
from django.conf import settings
from agreement.models import CompanyAgreement, MarketingPartnerAgreement
from .serializers import CompanyAgreementCreateSerializer, MarketingPartnerAgreementCreateSerializer
from agreement.s3_upload import upload_file_to_s3


class CompanyAgreementCreateAPIView(APIView):

    authentication_classes = [
        JWTAuthentication
    ]

    permission_classes = [
        IsAuthenticated
    ]

    parser_classes = [
        MultiPartParser,
        FormParser
    ]

    @transaction.atomic
    def post(self, request):

        try:

            # =====================================================
            # 1. Agreement Products
            # =====================================================

            agreement_products = request.data.get(
                'agreement_products'
            )

            if agreement_products is None:

                return Response(
                    {
                        "success": False,
                        "message": "Validation failed.",
                        "errors": {
                            "agreement_products": [
                                "This field is required."
                            ]
                        }
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =====================================================
            # 2. JSON string -> Python
            # =====================================================

            if isinstance(
                agreement_products,
                str
            ):

                try:

                    agreement_products = json.loads(
                        agreement_products
                    )

                except json.JSONDecodeError:

                    return Response(
                        {
                            "success": False,
                            "message": "Validation failed.",
                            "errors": {
                                "agreement_products": [
                                    "Invalid JSON format."
                                ]
                            }
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

            # =====================================================
            # 3. Single object OR list
            # =====================================================

            if isinstance(
                agreement_products,
                dict
            ):

                agreement_products = [
                    agreement_products
                ]

            elif isinstance(
                agreement_products,
                list
            ):

                pass

            else:

                return Response(
                    {
                        "success": False,
                        "message": "Validation failed.",
                        "errors": {
                            "agreement_products": [
                                "Must be an object or a list."
                            ]
                        }
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not agreement_products:

                return Response(
                    {
                        "success": False,
                        "message": "Validation failed.",
                        "errors": {
                            "agreement_products": [
                                "At least one product is required."
                            ]
                        }
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =====================================================
            # 4. Uploaded files
            # =====================================================

            qnx_mart_sign = request.FILES.get(
                'qnx_mart_sign_s3_key'
            )

            company_sign = request.FILES.get(
                'company_sign_s3_key'
            )

            qnx_mart_picture = request.FILES.get(
                'qnx_mart_picture_s3_key'
            )

            company_picture = request.FILES.get(
                'company_picture_s3_key'
            )

            uploaded_agreement_pdf = request.FILES.get(
                'uploaded_agreement_pdf_s3_key'
            )

            # =====================================================
            # 5. Build normal dictionary
            #    DO NOT use request.data.copy()
            # =====================================================

            data = {}

            normal_fields = [
                'agreement_number',
                'company',
                'agreement_role',
                'apply_on_all_products',
                'agreement_start_date',
                'agreement_end_date',
                'company_owner_name',
                'company_address',
                'seller_adhar_number',
                'owner_adhar_number',
                'seller_pan_number',
                'owner_pan_number',
                'additional_points',
                'qnx_mart_representative',
                'remarks'
            ]

            for field in normal_fields:

                value = request.data.get(field)

                if value is not None:
                    data[field] = value

            # =====================================================
            # 6. Add normalized products
            # =====================================================

            data['agreement_products'] = agreement_products

            # =====================================================
            # 7. Upload files to S3
            # =====================================================

            uploaded_files = {}

            # -----------------------------------------------------
            # QNX Mart Sign
            # -----------------------------------------------------

            if qnx_mart_sign:

                result = upload_file_to_s3(
                    qnx_mart_sign,
                    folder="agreements/qnx_mart_sign"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload QNX Mart signature."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data['qnx_mart_sign_s3_key'] = result['key']

                uploaded_files[
                    'qnx_mart_sign'
                ] = result

            # -----------------------------------------------------
            # Company Sign
            # -----------------------------------------------------

            if company_sign:

                result = upload_file_to_s3(
                    company_sign,
                    folder="agreements/company_sign"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload company signature."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data['company_sign_s3_key'] = result['key']

                uploaded_files[
                    'company_sign'
                ] = result

            # -----------------------------------------------------
            # QNX Mart Picture
            # -----------------------------------------------------

            if qnx_mart_picture:

                result = upload_file_to_s3(
                    qnx_mart_picture,
                    folder="agreements/qnx_mart_picture"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload QNX Mart picture."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'qnx_mart_picture_s3_key'
                ] = result['key']

                uploaded_files[
                    'qnx_mart_picture'
                ] = result

            # -----------------------------------------------------
            # Company Picture
            # -----------------------------------------------------

            if company_picture:

                result = upload_file_to_s3(
                    company_picture,
                    folder="agreements/company_picture"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload company picture."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'company_picture_s3_key'
                ] = result['key']

                uploaded_files[
                    'company_picture'
                ] = result

            # -----------------------------------------------------
            # Agreement PDF
            # -----------------------------------------------------

            if uploaded_agreement_pdf:

                result = upload_file_to_s3(
                    uploaded_agreement_pdf,
                    folder="agreements/pdf"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload agreement PDF."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'uploaded_agreement_pdf_s3_key'
                ] = result['key']

                uploaded_files[
                    'uploaded_agreement_pdf'
                ] = result

            # =====================================================
            # 8. Serializer
            # =====================================================

            serializer = CompanyAgreementCreateSerializer(
                data=data
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

            # =====================================================
            # 9. Save Agreement
            # =====================================================

            agreement = serializer.save(
                created_by=request.user
            )

            # =====================================================
            # 10. Agreement Products
            # =====================================================

            agreement_products_qs = (
                agreement.agreement_products
                .select_related('product')
                .all()
            )

            products_data = []

            for item in agreement_products_qs:

                products_data.append(
                    {
                        "product_id": item.product_id,
                        "product_name": item.product.name,
                        "profit_percentage":
                            item.profit_percentage,
                        "is_active":
                            item.is_active
                    }
                )

            # =====================================================
            # 11. Response
            # =====================================================

            return Response(
                {
                    "success": True,
                    "message":
                        "Company agreement created successfully.",
                    "data": {
                        "agreement_id":
                            agreement.id,

                        "agreement_number":
                            agreement.agreement_number,

                        "company_id":
                            agreement.company_id,

                        "agreement_role":
                            agreement.agreement_role,

                        "apply_on_all_products":
                            agreement.apply_on_all_products,

                        "agreement_start_date":
                            agreement.agreement_start_date,

                        "agreement_end_date":
                            agreement.agreement_end_date,

                        "status":
                            agreement.status,

                        "created_by":
                            agreement.created_by_id,

                        "qnx_mart_sign_s3_key":
                            agreement.qnx_mart_sign_s3_key,

                        "company_sign_s3_key":
                            agreement.company_sign_s3_key,

                        "qnx_mart_picture_s3_key":
                            agreement.qnx_mart_picture_s3_key,

                        "company_picture_s3_key":
                            agreement.company_picture_s3_key,

                        "uploaded_agreement_pdf_s3_key":
                            agreement.uploaded_agreement_pdf_s3_key,

                        "products":
                            products_data,

                        "uploaded_files":
                            uploaded_files
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            traceback.print_exc()

            return Response(
                {
                    "success": False,
                    "message":
                        "Failed to create company agreement.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
            
class MarketingPartnerAgreementCreateAPIView(APIView):

    authentication_classes = [
        JWTAuthentication
    ]

    permission_classes = [
        IsAuthenticated
    ]

    parser_classes = [
        MultiPartParser,
        FormParser
    ]

    @transaction.atomic
    def post(self, request):

        try:

            # =====================================================
            # 1. Get Marketing Partner
            # =====================================================

            marketing_partner = request.data.get(
                'marketing_partner'
            )

            if not marketing_partner:

                return Response(
                    {
                        "success": False,
                        "message": "Validation failed.",
                        "errors": {
                            "marketing_partner": [
                                "This field is required."
                            ]
                        }
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =====================================================
            # 2. Get uploaded files
            # =====================================================

            qnx_mart_sign = request.FILES.get(
                'qnx_mart_sign_s3_key'
            )

            marketing_partner_sign = request.FILES.get(
                'marketing_partner_sign_s3_key'
            )

            qnx_mart_picture = request.FILES.get(
                'qnx_mart_picture_s3_key'
            )

            marketing_partner_picture = request.FILES.get(
                'marketing_partner_picture_s3_key'
            )

            uploaded_agreement_pdf = request.FILES.get(
                'uploaded_agreement_pdf_s3_key'
            )

            # =====================================================
            # 3. Build normal dictionary
            # =====================================================

            data = {}

            fields = [
                'agreement_number',
                'marketing_partner',
                'agreement_role',
                'agreement_start_date',
                'agreement_end_date',

                'marketing_partner_name',
                'marketing_partner_address',

                'company_commission_percentage',
                'profit_share_percentage',
                'selling_commission_percentage',

                'additional_points',
                'qnx_mart_representative',

                'remarks'
            ]

            for field in fields:

                value = request.data.get(field)

                if value is not None:

                    data[field] = value

            # =====================================================
            # 4. Upload QNX Mart Sign
            # =====================================================

            if qnx_mart_sign:

                result = upload_file_to_s3(
                    qnx_mart_sign,
                    folder="marketing_partner_agreements/qnx_mart_sign"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload QNX Mart signature."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'qnx_mart_sign_s3_key'
                ] = result['key']

            # =====================================================
            # 5. Upload Marketing Partner Sign
            # =====================================================

            if marketing_partner_sign:

                result = upload_file_to_s3(
                    marketing_partner_sign,
                    folder="marketing_partner_agreements/partner_sign"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload marketing partner signature."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'marketing_partner_sign_s3_key'
                ] = result['key']

            # =====================================================
            # 6. Upload QNX Mart Picture
            # =====================================================

            if qnx_mart_picture:

                result = upload_file_to_s3(
                    qnx_mart_picture,
                    folder="marketing_partner_agreements/qnx_mart_picture"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload QNX Mart picture."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'qnx_mart_picture_s3_key'
                ] = result['key']

            # =====================================================
            # 7. Upload Marketing Partner Picture
            # =====================================================

            if marketing_partner_picture:

                result = upload_file_to_s3(
                    marketing_partner_picture,
                    folder="marketing_partner_agreements/partner_picture"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload marketing partner picture."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'marketing_partner_picture_s3_key'
                ] = result['key']

            # =====================================================
            # 8. Upload Agreement PDF
            # =====================================================

            if uploaded_agreement_pdf:

                result = upload_file_to_s3(
                    uploaded_agreement_pdf,
                    folder="marketing_partner_agreements/pdf"
                )

                if not result:

                    return Response(
                        {
                            "success": False,
                            "message":
                                "Failed to upload agreement PDF."
                        },
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

                data[
                    'uploaded_agreement_pdf_s3_key'
                ] = result['key']

            # =====================================================
            # 9. Serializer
            # =====================================================

            serializer = MarketingPartnerAgreementCreateSerializer(
                data=data
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

            # =====================================================
            # 10. Save
            # =====================================================

            agreement = serializer.save(
                created_by=request.user
            )

            # =====================================================
            # 11. Response
            # =====================================================

            return Response(
            {
                "success": True,
                "message":
                    "Marketing partner agreement created successfully.",

                "data": {

                    "agreement_id":
                        agreement.id,

                    "agreement_number":
                        agreement.agreement_number,

                    "marketing_partner_id":
                        agreement.marketing_partner_id,

                    "agreement_role":
                        agreement.agreement_role,

                    "agreement_start_date":
                        agreement.agreement_start_date,

                    "agreement_end_date":
                        agreement.agreement_end_date,

                    "marketing_partner_name":
                        agreement.marketing_partner_name,

                    "marketing_partner_address":
                        agreement.marketing_partner_address,

                    "company_commission_percentage":
                        agreement.company_commission_percentage,

                    "profit_share_percentage":
                        agreement.profit_share_percentage,

                    "selling_commission_percentage":
                        agreement.selling_commission_percentage,

                    "additional_points":
                        agreement.additional_points,

                    "qnx_mart_representative":
                        agreement.qnx_mart_representative,

                    "remarks":
                        agreement.remarks,

                    "status":
                        agreement.status,

                    "created_by":
                        agreement.created_by_id,

                    # ==========================================
                    # S3 URLs
                    # ==========================================

                    "qnx_mart_sign_url": (
                        f"https://"
                        f"{settings.AWS_STORAGE_BUCKET_NAME}"
                        f".s3.amazonaws.com/"
                        f"{agreement.qnx_mart_sign_s3_key}"
                        if agreement.qnx_mart_sign_s3_key
                        else None
                    ),

                    "marketing_partner_sign_url": (
                        f"https://"
                        f"{settings.AWS_STORAGE_BUCKET_NAME}"
                        f".s3.amazonaws.com/"
                        f"{agreement.marketing_partner_sign_s3_key}"
                        if agreement.marketing_partner_sign_s3_key
                        else None
                    ),

                    "qnx_mart_picture_url": (
                        f"https://"
                        f"{settings.AWS_STORAGE_BUCKET_NAME}"
                        f".s3.amazonaws.com/"
                        f"{agreement.qnx_mart_picture_s3_key}"
                        if agreement.qnx_mart_picture_s3_key
                        else None
                    ),

                    "marketing_partner_picture_url": (
                        f"https://"
                        f"{settings.AWS_STORAGE_BUCKET_NAME}"
                        f".s3.amazonaws.com/"
                        f"{agreement.marketing_partner_picture_s3_key}"
                        if agreement.marketing_partner_picture_s3_key
                        else None
                    ),

                    "uploaded_agreement_pdf_url": (
                        f"https://"
                        f"{settings.AWS_STORAGE_BUCKET_NAME}"
                        f".s3.amazonaws.com/"
                        f"{agreement.uploaded_agreement_pdf_s3_key}"
                        if agreement.uploaded_agreement_pdf_s3_key
                        else None
                    )
                }
            },
            status=status.HTTP_201_CREATED
        )

        except Exception as e:

            traceback.print_exc()

            return Response(
                {
                    "success": False,
                    "message":
                        "Failed to create marketing partner agreement.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
            
class MarketingPartnerAgreementListAPIView(APIView):

    def post(self, request):

        try:

            agreements = (
                MarketingPartnerAgreement.objects
                .select_related(
                    'marketing_partner',
                    'created_by',
                    'approved_by'
                )
                .order_by('-created_at')
            )

            # -----------------------------------------
            # S3 URL Helper
            # -----------------------------------------
            def s3_url(key):

                if not key:
                    return None

                return (
                    f"https://"
                    f"{settings.AWS_STORAGE_BUCKET_NAME}"
                    f".s3.amazonaws.com/"
                    f"{key}"
                )

            data = []

            for agreement in agreements:

                data.append({

                    "agreement_id": agreement.id,

                    "agreement_number": (
                        agreement.agreement_number
                    ),

                    "marketing_partner_id": (
                        agreement.marketing_partner_id
                    ),

                    "marketing_partner_name": (
                        agreement.marketing_partner_name
                    ),

                    "agreement_role": (
                        agreement.agreement_role
                    ),

                    "agreement_start_date": (
                        agreement.agreement_start_date
                    ),

                    "agreement_end_date": (
                        agreement.agreement_end_date
                    ),

                    "marketing_partner_address": (
                        agreement.marketing_partner_address
                    ),
                    "adhar_number": (
                        agreement.adhar_number
                    ),
                    "pan_number": (
                        agreement.pan_number
                    ),

                    # ---------------------------------
                    # Commission
                    # ---------------------------------

                    "company_commission_percentage": (
                        str(
                            agreement.company_commission_percentage
                        )
                    ),

                    "profit_share_percentage": (
                        str(
                            agreement.profit_share_percentage
                        )
                    ),

                    "selling_commission_percentage": (
                        str(
                            agreement.selling_commission_percentage
                        )
                    ),

                    # ---------------------------------
                    # Other Details
                    # ---------------------------------

                    "additional_points": (
                        agreement.additional_points
                    ),

                    "qnx_mart_representative": (
                        agreement.qnx_mart_representative
                    ),

                    "remarks": agreement.remarks,

                    # ---------------------------------
                    # S3 URLs
                    # ---------------------------------

                    "qnx_mart_sign_url": s3_url(
                        agreement.qnx_mart_sign_s3_key
                    ),

                    "marketing_partner_sign_url": s3_url(
                        agreement.marketing_partner_sign_s3_key
                    ),

                    "qnx_mart_picture_url": s3_url(
                        agreement.qnx_mart_picture_s3_key
                    ),

                    "marketing_partner_picture_url": s3_url(
                        agreement.marketing_partner_picture_s3_key
                    ),

                    "uploaded_agreement_pdf_url": s3_url(
                        agreement.uploaded_agreement_pdf_s3_key
                    ),

                    # ---------------------------------
                    # Status
                    # ---------------------------------

                    "status": agreement.status,

                    "created_by": (
                        agreement.created_by_id
                    ),

                    "approved_by": (
                        agreement.approved_by_id
                    ),

                    "approved_at": (
                        agreement.approved_at
                    ),

                    "rejection_reason": (
                        agreement.rejection_reason
                    ),

                    "created_at": (
                        agreement.created_at
                    ),

                    "updated_at": (
                        agreement.updated_at
                    )
                })

            return Response(
                {
                    "success": True,
                    "message": (
                        "Marketing Partner Agreements "
                        "fetched successfully."
                    ),
                    "count": len(data),
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": (
                        "Failed to fetch Marketing Partner Agreements."
                    ),
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
            
            
class CompanyAgreementListAPIView(APIView):

    authentication_classes = [
        JWTAuthentication
    ]

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request):

        try:

            agreements = (
                CompanyAgreement.objects
                .select_related(
                    'company',
                    'created_by',
                    'approved_by'
                )
                .prefetch_related(
                    'agreement_products__product'
                )
                .order_by('-created_at')
            )

            data = []

            for agreement in agreements:

                # ==========================================
                # Products
                # ==========================================

                products_data = []

                for item in agreement.agreement_products.all():

                    products_data.append(
                        {
                            "product_id":
                                item.product_id,

                            "product_name":
                                item.product.name,

                            "profit_percentage":
                                item.profit_percentage,

                            "is_active":
                                item.is_active
                        }
                    )

                # ==========================================
                # S3 URL helper
                # ==========================================

                def s3_url(key):

                    if not key:
                        return None

                    return (
                        f"https://"
                        f"{settings.AWS_STORAGE_BUCKET_NAME}"
                        f".s3.amazonaws.com/"
                        f"{key}"
                    )

                # ==========================================
                # Agreement data
                # ==========================================

                data.append(
                    {
                        "agreement_id":
                            agreement.id,

                        "agreement_number":
                            agreement.agreement_number,

                        "company_id":
                            agreement.company_id,

                        "company_name":
                            getattr(
                                agreement.company,
                                'name',
                                None
                            ),

                        "agreement_role":
                            agreement.agreement_role,

                        "apply_on_all_products":
                            agreement.apply_on_all_products,

                        "agreement_start_date":
                            agreement.agreement_start_date,

                        "agreement_end_date":
                            agreement.agreement_end_date,

                        "company_owner_name":
                            agreement.company_owner_name,

                        "company_address":
                            agreement.company_address,

                        "seller_adhar_number":
                            agreement.seller_adhar_number,

                        "owner_adhar_number":
                            agreement.owner_adhar_number,

                        "seller_pan_number":
                            agreement.seller_pan_number,

                        "owner_pan_number":
                            agreement.owner_pan_number,

                        "additional_points":
                            agreement.additional_points,

                        "qnx_mart_representative":
                            agreement.qnx_mart_representative,

                        # ==================================
                        # S3 URLs
                        # ==================================

                        "qnx_mart_sign_url":
                            s3_url(
                                agreement.qnx_mart_sign_s3_key
                            ),

                        "company_sign_url":
                            s3_url(
                                agreement.company_sign_s3_key
                            ),

                        "qnx_mart_picture_url":
                            s3_url(
                                agreement.qnx_mart_picture_s3_key
                            ),

                        "company_picture_url":
                            s3_url(
                                agreement.company_picture_s3_key
                            ),

                        "uploaded_agreement_pdf_url":
                            s3_url(
                                agreement.uploaded_agreement_pdf_s3_key
                            ),

                        "remarks":
                            agreement.remarks,

                        "status":
                            agreement.status,

                        "created_by":
                            agreement.created_by_id,

                        "approved_by":
                            agreement.approved_by_id,

                        "approved_at":
                            agreement.approved_at,

                        "rejection_reason":
                            agreement.rejection_reason,

                        "created_at":
                            agreement.created_at,

                        "updated_at":
                            agreement.updated_at,

                        # ==================================
                        # Products
                        # ==================================

                        "products":
                            products_data
                    }
                )

            return Response(
                {
                    "success": True,
                    "message":
                        "Company agreements fetched successfully.",
                    "count":
                        len(data),
                    "data":
                        data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            import traceback
            traceback.print_exc()

            return Response(
                {
                    "success": False,
                    "message":
                        "Failed to fetch company agreements.",
                    "error":
                        str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR) 
            
            
class CompanyAgreementStatusAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:
            # -----------------------------------------
            # Request Data
            # -----------------------------------------
            agreement_id = request.data.get("agreement_id")
            action = request.data.get("status")
            rejection_reason = request.data.get(
                "rejection_reason"
            )

            # -----------------------------------------
            # Validate Agreement ID
            # -----------------------------------------
            if not agreement_id:
                return Response(
                    {
                        "success": False,
                        "message": "agreement_id is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Validate Status
            # -----------------------------------------
            if action not in ["approved", "rejected"]:

                return Response(
                    {
                        "success": False,
                        "message": (
                            "status must be either "
                            "'approved' or 'rejected'."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Rejection Reason Required
            # -----------------------------------------
            if action == "rejected" and not rejection_reason:

                return Response(
                    {
                        "success": False,
                        "message": (
                            "rejection_reason is required "
                            "when rejecting agreement."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Get Agreement
            # -----------------------------------------
            try:
                agreement = CompanyAgreement.objects.get(
                    id=agreement_id
                )

            except CompanyAgreement.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Company Agreement not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # -----------------------------------------
            # Already Approved
            # -----------------------------------------
            if (
                agreement.status == "approved"
                and action == "approved"
            ):

                return Response(
                    {
                        "success": False,
                        "message": (
                            "Company Agreement is already approved."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Already Rejected
            # -----------------------------------------
            if (
                agreement.status == "rejected"
                and action == "rejected"
            ):

                return Response(
                    {
                        "success": False,
                        "message": (
                            "Company Agreement is already rejected."
                        ),
                        "data": {
                            "agreement_id": agreement.id,
                            "status": agreement.status,
                            "rejection_reason": (
                                agreement.rejection_reason
                            )
                        }
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =========================================
            # APPROVE
            # =========================================
            if action == "approved":

                agreement.status = "approved"
                agreement.approved_by = request.user
                agreement.approved_at = timezone.now()
                agreement.rejection_reason = None

                agreement.save(
                    update_fields=[
                        "status",
                        "approved_by",
                        "approved_at",
                        "rejection_reason",
                        "updated_at"
                    ]
                )

                return Response(
                    {
                        "success": True,
                        "message": (
                            "Company Agreement "
                            "approved successfully."
                        ),
                        "data": {
                            "agreement_id": agreement.id,
                            "agreement_number": (
                                agreement.agreement_number
                            ),
                            "company_id": agreement.company_id,
                            "status": agreement.status,
                            "approved_by": (
                                agreement.approved_by_id
                            ),
                            "approved_at": (
                                agreement.approved_at
                            )
                        }
                    },
                    status=status.HTTP_200_OK
                )

            # =========================================
            # REJECT
            # =========================================
            if action == "rejected":

                agreement.status = "rejected"
                agreement.rejection_reason = rejection_reason

                # Clear approval information
                agreement.approved_by = None
                agreement.approved_at = None

                agreement.save(
                    update_fields=[
                        "status",
                        "rejection_reason",
                        "approved_by",
                        "approved_at",
                        "updated_at"
                    ]
                )

                return Response(
                    {
                        "success": True,
                        "message": (
                            "Company Agreement "
                            "rejected successfully."
                        ),
                        "data": {
                            "agreement_id": agreement.id,
                            "agreement_number": (
                                agreement.agreement_number
                            ),
                            "company_id": agreement.company_id,
                            "status": agreement.status,
                            "rejection_reason": (
                                agreement.rejection_reason
                            )
                        }
                    },
                    status=status.HTTP_200_OK
                )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": (
                        "Failed to update Company Agreement status."
                    ),
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
class MyCompanyApprovedAgreementAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:

            # -----------------------------------------
            # Logged-in user's company agreements
            # -----------------------------------------
            agreements = (
                CompanyAgreement.objects
                .select_related("company")
                .prefetch_related("agreement_products__product")
                .filter(
                    company__user=request.user,
                    status="approved"
                )
                .order_by("-approved_at")
            )

            # -----------------------------------------
            # S3 URL Helper
            # -----------------------------------------
            def s3_url(key):

                if not key:
                    return None

                return (
                    f"https://"
                    f"{settings.AWS_STORAGE_BUCKET_NAME}"
                    f".s3.amazonaws.com/"
                    f"{key}"
                )

            data = []

            for agreement in agreements:

                products = []

                for agreement_product in agreement.agreement_products.all():

                    products.append({
                        "product_id": agreement_product.product_id,
                        "product_name": (
                            agreement_product.product.name
                            if agreement_product.product
                            else None
                        ),
                        "profit_percentage": (
                            str(agreement_product.profit_percentage)
                            if agreement_product.profit_percentage is not None
                            else None
                        ),
                        "is_active": agreement_product.is_active
                    })

                data.append({

                    "agreement_id": agreement.id,

                    "agreement_number": (
                        agreement.agreement_number
                    ),

                    "company_id": agreement.company_id,

                    "company_name": (
                        agreement.company.name
                        if agreement.company
                        else None
                    ),

                    "agreement_role": (
                        agreement.agreement_role
                    ),

                    "apply_on_all_products": (
                        agreement.apply_on_all_products
                    ),

                    "agreement_start_date": (
                        agreement.agreement_start_date
                    ),

                    "agreement_end_date": (
                        agreement.agreement_end_date
                    ),

                    "company_owner_name": (
                        agreement.company_owner_name
                    ),

                    "company_address": (
                        agreement.company_address
                    ),

                    "seller_adhar_number": (
                        agreement.seller_adhar_number
                    ),

                    "owner_adhar_number": (
                        agreement.owner_adhar_number
                    ),

                    "seller_pan_number": (
                        agreement.seller_pan_number
                    ),

                    "owner_pan_number": (
                        agreement.owner_pan_number
                    ),

                    "additional_points": (
                        agreement.additional_points
                    ),

                    "qnx_mart_representative": (
                        agreement.qnx_mart_representative
                    ),

                    # ---------------------------------
                    # S3 URLs
                    # ---------------------------------

                    "qnx_mart_sign_url": s3_url(
                        agreement.qnx_mart_sign_s3_key
                    ),

                    "company_sign_url": s3_url(
                        agreement.company_sign_s3_key
                    ),

                    "qnx_mart_picture_url": s3_url(
                        agreement.qnx_mart_picture_s3_key
                    ),

                    "company_picture_url": s3_url(
                        agreement.company_picture_s3_key
                    ),

                    "uploaded_agreement_pdf_url": s3_url(
                        agreement.uploaded_agreement_pdf_s3_key
                    ),

                    "remarks": agreement.remarks,

                    "status": agreement.status,

                    "approved_by": (
                        agreement.approved_by_id
                    ),

                    "approved_at": (
                        agreement.approved_at
                    ),

                    "created_at": (
                        agreement.created_at
                    ),

                    "updated_at": (
                        agreement.updated_at
                    ),

                    "products": products
                })

            return Response(
                {
                    "success": True,
                    "message": (
                        "Approved company agreements "
                        "fetched successfully."
                    ),
                    "count": len(data),
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": (
                        "Failed to fetch company agreements."
                    ),
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
                        
class MarketingPartnerAgreementStatusAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:
            # -----------------------------------------
            # Request Data
            # -----------------------------------------
            agreement_id = request.data.get("agreement_id")
            action = request.data.get("status")
            rejection_reason = request.data.get(
                "rejection_reason"
            )

            # -----------------------------------------
            # Agreement ID Validation
            # -----------------------------------------
            if not agreement_id:
                return Response(
                    {
                        "success": False,
                        "message": "agreement_id is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Status Validation
            # -----------------------------------------
            if action not in ["approved", "rejected"]:
                return Response(
                    {
                        "success": False,
                        "message": (
                            "status must be either "
                            "'approved' or 'rejected'."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Rejection Reason Required
            # -----------------------------------------
            if action == "rejected" and not rejection_reason:
                return Response(
                    {
                        "success": False,
                        "message": (
                            "rejection_reason is required "
                            "when rejecting agreement."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Get Agreement
            # -----------------------------------------
            try:
                agreement = MarketingPartnerAgreement.objects.get(
                    id=agreement_id
                )

            except MarketingPartnerAgreement.DoesNotExist:
                return Response(
                    {
                        "success": False,
                        "message": (
                            "Marketing Partner Agreement "
                            "not found."
                        )
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # -----------------------------------------
            # Already Approved
            # -----------------------------------------
            if (
                agreement.status == "approved"
                and action == "approved"
            ):
                return Response(
                    {
                        "success": False,
                        "message": (
                            "Marketing Partner Agreement "
                            "is already approved."
                        ),
                        "data": {
                            "agreement_id": agreement.id,
                            "agreement_number": (
                                agreement.agreement_number
                            ),
                            "status": agreement.status,
                            "approved_by": (
                                agreement.approved_by_id
                            ),
                            "approved_at": (
                                agreement.approved_at
                            )
                        }
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # -----------------------------------------
            # Already Rejected
            # -----------------------------------------
            if (
                agreement.status == "rejected"
                and action == "rejected"
            ):
                return Response(
                    {
                        "success": False,
                        "message": (
                            "Marketing Partner Agreement "
                            "is already rejected."
                        ),
                        "data": {
                            "agreement_id": agreement.id,
                            "agreement_number": (
                                agreement.agreement_number
                            ),
                            "status": agreement.status,
                            "rejection_reason": (
                                agreement.rejection_reason
                            )
                        }
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =========================================
            # APPROVE
            # =========================================
            if action == "approved":

                agreement.status = "approved"
                agreement.approved_by = request.user
                agreement.approved_at = timezone.now()
                agreement.rejection_reason = None

                agreement.save(
                    update_fields=[
                        "status",
                        "approved_by",
                        "approved_at",
                        "rejection_reason",
                        "updated_at"
                    ]
                )

                return Response(
                    {
                        "success": True,
                        "message": (
                            "Marketing Partner Agreement "
                            "approved successfully."
                        ),
                        "data": {
                            "agreement_id": agreement.id,
                            "agreement_number": (
                                agreement.agreement_number
                            ),
                            "marketing_partner_id": (
                                agreement.marketing_partner_id
                            ),
                            "marketing_partner_name": (
                                agreement.marketing_partner_name
                            ),
                            "status": agreement.status,
                            "approved_by": (
                                agreement.approved_by_id
                            ),
                            "approved_at": (
                                agreement.approved_at
                            )
                        }
                    },
                    status=status.HTTP_200_OK
                )

            # =========================================
            # REJECT
            # =========================================
            if action == "rejected":

                agreement.status = "rejected"
                agreement.rejection_reason = rejection_reason

                # Clear approval information
                agreement.approved_by = None
                agreement.approved_at = None

                agreement.save(
                    update_fields=[
                        "status",
                        "rejection_reason",
                        "approved_by",
                        "approved_at",
                        "updated_at"
                    ]
                )

                return Response(
                    {
                        "success": True,
                        "message": (
                            "Marketing Partner Agreement "
                            "rejected successfully."
                        ),
                        "data": {
                            "agreement_id": agreement.id,
                            "agreement_number": (
                                agreement.agreement_number
                            ),
                            "marketing_partner_id": (
                                agreement.marketing_partner_id
                            ),
                            "marketing_partner_name": (
                                agreement.marketing_partner_name
                            ),
                            "status": agreement.status,
                            "rejection_reason": (
                                agreement.rejection_reason
                            )
                        }
                    },
                    status=status.HTTP_200_OK
                )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": (
                        "Failed to update Marketing Partner "
                        "Agreement status."
                    ),
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
            
class MyMarketingPartnerAgreementListAPIView(APIView):

    authentication_classes = [
        JWTAuthentication
    ]

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request):

        try:

            # -----------------------------------------
            # Get logged-in Marketing Partner
            # -----------------------------------------

            agreements = (
                MarketingPartnerAgreement.objects
                .filter(
                    marketing_partner__user=request.user,
                    status="approved"
                )
                .select_related(
                    'marketing_partner',
                    'created_by',
                    'approved_by'
                )
                .order_by('-created_at')
            )

            # -----------------------------------------
            # S3 URL Helper
            # -----------------------------------------

            def s3_url(key):

                if not key:
                    return None

                return (
                    f"https://"
                    f"{settings.AWS_STORAGE_BUCKET_NAME}"
                    f".s3.amazonaws.com/"
                    f"{key}"
                )

            # -----------------------------------------
            # Response Data
            # -----------------------------------------

            data = []

            for agreement in agreements:

                data.append({

                    # ---------------------------------
                    # Agreement
                    # ---------------------------------

                    "agreement_id": agreement.id,

                    "agreement_number": (
                        agreement.agreement_number
                    ),

                    "agreement_role": (
                        agreement.agreement_role
                    ),

                    "agreement_start_date": (
                        agreement.agreement_start_date
                    ),

                    "agreement_end_date": (
                        agreement.agreement_end_date
                    ),

                    # ---------------------------------
                    # Marketing Partner
                    # ---------------------------------

                    "marketing_partner_id": (
                        agreement.marketing_partner_id
                    ),

                    "marketing_partner_name": (
                        agreement.marketing_partner_name
                    ),

                    "marketing_partner_address": (
                        agreement.marketing_partner_address
                    ),

                    # ---------------------------------
                    # Commission
                    # ---------------------------------

                    "company_commission_percentage": str(
                        agreement.company_commission_percentage
                    ),

                    "profit_share_percentage": str(
                        agreement.profit_share_percentage
                    ),

                    "selling_commission_percentage": str(
                        agreement.selling_commission_percentage
                    ),

                    # ---------------------------------
                    # Additional Details
                    # ---------------------------------

                    "additional_points": (
                        agreement.additional_points
                    ),

                    "qnx_mart_representative": (
                        agreement.qnx_mart_representative
                    ),

                    "remarks": (
                        agreement.remarks
                    ),

                    # ---------------------------------
                    # QNX Mart Sign
                    # ---------------------------------

                    "qnx_mart_sign_url": s3_url(
                        agreement.qnx_mart_sign_s3_key
                    ),

                    # ---------------------------------
                    # Marketing Partner Sign
                    # ---------------------------------

                    "marketing_partner_sign_url": s3_url(
                        agreement.marketing_partner_sign_s3_key
                    ),

                    # ---------------------------------
                    # QNX Mart Picture
                    # ---------------------------------

                    "qnx_mart_picture_url": s3_url(
                        agreement.qnx_mart_picture_s3_key
                    ),

                    # ---------------------------------
                    # Marketing Partner Picture
                    # ---------------------------------

                    "marketing_partner_picture_url": s3_url(
                        agreement.marketing_partner_picture_s3_key
                    ),

                    # ---------------------------------
                    # Agreement PDF
                    # ---------------------------------

                    "uploaded_agreement_pdf_url": s3_url(
                        agreement.uploaded_agreement_pdf_s3_key
                    ),

                    # ---------------------------------
                    # Status
                    # ---------------------------------

                    "status": agreement.status,

                    # ---------------------------------
                    # Approval Details
                    # ---------------------------------

                    "approved_by": (
                        agreement.approved_by_id
                    ),

                    "approved_at": (
                        agreement.approved_at
                    ),

                    # ---------------------------------
                    # Created Details
                    # ---------------------------------

                    "created_by": (
                        agreement.created_by_id
                    ),

                    "created_at": (
                        agreement.created_at
                    ),

                    "updated_at": (
                        agreement.updated_at
                    )
                })

            # -----------------------------------------
            # Success Response
            # -----------------------------------------

            return Response(
                {
                    "success": True,

                    "message": (
                        "My approved Marketing Partner "
                        "Agreements fetched successfully."
                    ),

                    "count": len(data),

                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            # -----------------------------------------
            # Error Response
            # -----------------------------------------

            return Response(
                {
                    "success": False,

                    "message": (
                        "Failed to fetch my "
                        "Marketing Partner Agreements."
                    ),

                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            