import razorpay
from rest_framework.views import APIView, settings
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Q
from datetime import datetime, timedelta
from real_estate.whatsapp import send_whatsapp_meeting_message
from enquiry.models import MarketingPartner
from .models import Amenity, Property, PropertyEnquiry, Builder
from .serializers import AmenityCreateSerializer, ApprovedPropertyListSerializer, PropertyDetailSerializer, PropertyEnquiryCreateSerializer
from .serializers import (PropertyEnquiryFilterSerializer)
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication
from .serializers import BuilderSerializer
from django.utils import timezone
from .serializers import RealEstateChannelPartnerSerializer
from enquiry.serializers import MarketingPartnerSerializer
import razorpay
razorpay_client = razorpay.Client(
    auth=(
        settings.RAZORPAY_KEY_ID,
        settings.RAZORPAY_KEY_SECRET
    )
)


class BuilderCreateAPIView(APIView):

    def post(self, request):

        try:

            # ---------------------------------------
            # BUILDER DATA
            # ---------------------------------------

            data = request.data.copy()

            # Logo वेगळा handle करणार आहोत
            data.pop("logo", None)

            serializer = BuilderSerializer(
                data=data
            )

            # ---------------------------------------
            # VALIDATION
            # ---------------------------------------

            if not serializer.is_valid():

                return Response(
                    {
                        "success": False,
                        "message": "Builder creation failed",
                        "errors": serializer.errors
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ---------------------------------------
            # CREATE BUILDER
            # ---------------------------------------

            builder = serializer.save()

            # ---------------------------------------
            # GET LOGO
            # ---------------------------------------

            logo = request.FILES.get("logo")

            if logo:

                # -----------------------------------
                # UPLOAD TO S3
                # -----------------------------------

                logo_url = upload_to_s3(
                    logo,
                    f"builders/{builder.id}/logo"
                )

                # -----------------------------------
                # SAVE S3 URL
                # -----------------------------------

                builder.logo_s3_key = logo_url

                builder.save(
                    update_fields=["logo_s3_key"]
                )

            # ---------------------------------------
            # RESPONSE
            # ---------------------------------------

            response_serializer = BuilderSerializer(
                builder,
                context={
                    "request": request
                }
            )

            return Response(
                {
                    "success": True,
                    "message": "Builder created successfully",
                    "builder_id": builder.id,
                    "data": response_serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Builder creation failed",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
class BuilderListAPIView(APIView):

    def post(self, request):

        builders = Builder.objects.all().order_by("-created_at")

        serializer = BuilderSerializer(
            builders,
            many=True
        )

        return Response(
            {
                "success": True,
                "message": "Builders fetched successfully",
                "count": builders.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )

class AmenityCreateAPIView(APIView):

    def post(self, request):
        serializer = AmenityCreateSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()

            return Response(
                {
                    "status": True,
                    "message": "Amenity created successfully.",
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "status": False,
                "message": "Validation error.",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
        
class AmenityListAPIView(APIView):

    def post(self, request):

        amenities = Amenity.objects.all().order_by("-id")

        serializer = AmenityCreateSerializer(
            amenities,
            many=True
        )

        return Response(
            {
                "status": True,
                "message": "Amenities fetched successfully.",
                "count": amenities.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )        


        
from django.db import transaction
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .serializers import PropertyCreateSerializer, PropertyDetailSerializer
from .models import PropertyImage, PropertyVideo, PropertySubscriptionSetting
from .s3_upload import upload_to_s3


# class PropertyCreateAPIView(APIView):

#     @transaction.atomic
#     def post(self, request):

#         try:

#             serializer = PropertyCreateSerializer(
#                 data=request.data
#             )

#             if not serializer.is_valid():

#                 return Response(
#                     {
#                         "success": False,
#                         "message": "Property creation failed",
#                         "errors": serializer.errors
#                     },
#                     status=status.HTTP_400_BAD_REQUEST
#                 )

#             property_obj = serializer.save()

#             # ---------------------------------------
#             # IMAGES UPLOAD TO S3
#             # ---------------------------------------

#             images = request.FILES.getlist("images")

#             for image in images:

#                 image_url = upload_to_s3(
#                     image,
#                     f"properties/{property_obj.id}/images"
#                 )

#                 PropertyImage.objects.create(
#                     property=property_obj,

#                     # Model field name
#                     image_s3_key=image_url,

#                     image_type=request.data.get(
#                         "image_type",
#                         "other"
#                     ),

#                     caption=request.data.get(
#                         "image_caption",
#                         ""
#                     ),

#                     is_primary=False
#                 )

#             # ---------------------------------------
#             # VIDEOS UPLOAD TO S3
#             # ---------------------------------------

#             videos = request.FILES.getlist("videos")

#             for video in videos:

#                 video_url = upload_to_s3(
#                     video,
#                     f"properties/{property_obj.id}/videos"
#                 )

#                 PropertyVideo.objects.create(
#                     property=property_obj,

#                     # Model field name
#                     video_s3_key=video_url,

#                     title=request.data.get(
#                         "video_title",
#                         ""
#                     ),

#                     is_featured=False
#                 )

#             # ---------------------------------------
#             # RESPONSE
#             # ---------------------------------------

#             response_serializer = PropertyDetailSerializer(
#                 property_obj,
#                 context={
#                     "request": request
#                 }
#             )

#             return Response(
#                 {
#                     "success": True,
#                     "message": "Property created successfully",
#                     "property_id": property_obj.id,
#                     "data": response_serializer.data
#                 },
#                 status=status.HTTP_201_CREATED
#             )

#         except Exception as e:

#             return Response(
#                 {
#                     "success": False,
#                     "message": "Property creation failed",
#                     "error": str(e)
#                 },
#                 status=status.HTTP_500_INTERNAL_SERVER_ERROR
#             )
# class PropertyCreateAPIView(APIView):

#     authentication_classes = [JWTAuthentication]
#     permission_classes = [IsAuthenticated]

#     @transaction.atomic
#     def post(self, request):

#         try:

#             # ---------------------------------------
#             # LOGGED-IN USER
#             # ---------------------------------------

#             logged_in_user = request.user

#             # ---------------------------------------
#             # SERIALIZER VALIDATION
#             # ---------------------------------------

#             serializer = PropertyCreateSerializer(
#                 data=request.data
#             )

#             if not serializer.is_valid():

#                 return Response(
#                     {
#                         "success": False,
#                         "message": "Property creation failed",
#                         "errors": serializer.errors
#                     },
#                     status=status.HTTP_400_BAD_REQUEST
#                 )

#             # ---------------------------------------
#             # GET SOURCE
#             # ---------------------------------------

#             property_source = request.data.get(
#                 "source",
#                 "website"
#             )

#             property_source = str(
#                 property_source
#             ).strip().lower()

#             # ---------------------------------------
#             # CURRENT TIME
#             # ---------------------------------------

#             current_time = timezone.now()

#             # ---------------------------------------
#             # SUBSCRIPTION LOGIC
#             # ---------------------------------------

#             if property_source == "admin":

#                 # =======================================
#                 # ADMIN PROPERTY
#                 # ALWAYS FREE
#                 # =======================================

#                 free_days = None
#                 free_expiry_date = None
#                 subscription_required = False
#                 subscription_active = True

#             else:

#                 # =======================================
#                 # WEBSITE PROPERTY
#                 # DYNAMIC FREE DAYS
#                 # =======================================

#                 setting = PropertySubscriptionSetting.objects.filter(
#                     is_active=True
#                 ).first()

#                 if setting:
#                     free_days = setting.free_days
#                 else:
#                     free_days = 15

#                 # ---------------------------------------
#                 # FREE EXPIRY DATE
#                 # ---------------------------------------

#                 free_expiry_date = (
#                     current_time +
#                     timedelta(days=free_days)
#                 )

#                 # ---------------------------------------
#                 # SUBSCRIPTION REQUIRED
#                 # ---------------------------------------

#                 subscription_required = (
#                     free_days == 0
#                 )

#                 subscription_active = False

#             # ---------------------------------------
#             # PROPERTY CREATE
#             # ---------------------------------------

#             property_obj = serializer.save(

#                 # Source
#                 source=property_source,

#                 # Logged-in user becomes agent
#                 agent=logged_in_user,

#                 # Subscription
#                 free_days=free_days,

#                 free_expiry_date=free_expiry_date,

#                 subscription_required=subscription_required,

#                 subscription_active=subscription_active
#             )

#             # ---------------------------------------
#             # IMAGES UPLOAD TO S3
#             # ---------------------------------------

#             images = request.FILES.getlist("images")

#             for image in images:

#                 image_url = upload_to_s3(
#                     image,
#                     f"properties/{property_obj.id}/images"
#                 )

#                 PropertyImage.objects.create(

#                     property=property_obj,

#                     image_s3_key=image_url,

#                     image_type=request.data.get(
#                         "image_type",
#                         "other"
#                     ),

#                     caption=request.data.get(
#                         "image_caption",
#                         ""
#                     ),

#                     is_primary=False
#                 )

#             # ---------------------------------------
#             # VIDEOS UPLOAD TO S3
#             # ---------------------------------------

#             videos = request.FILES.getlist("videos")

#             for video in videos:

#                 video_url = upload_to_s3(
#                     video,
#                     f"properties/{property_obj.id}/videos"
#                 )

#                 PropertyVideo.objects.create(
#                     property=property_obj,
#                     video_s3_key=video_url
#                 )

#             # ---------------------------------------
#             # RESPONSE SERIALIZER
#             # ---------------------------------------

#             response_serializer = PropertyDetailSerializer(
#                 property_obj,
#                 context={
#                     "request": request
#                 }
#             )

#             # ---------------------------------------
#             # SUCCESS RESPONSE
#             # ---------------------------------------

#             return Response(
#                 {
#                     "success": True,

#                     "message": "Property created successfully",

#                     "property_id": property_obj.id,

#                     "subscription": {

#                         "source": property_obj.source,

#                         "free_days": property_obj.free_days,

#                         "free_expiry_date":
#                             property_obj.free_expiry_date,

#                         "subscription_required":
#                             property_obj.subscription_required,

#                         "subscription_active":
#                             property_obj.subscription_active
#                     },

#                     "data": response_serializer.data
#                 },

#                 status=status.HTTP_201_CREATED
#             )

#         # ---------------------------------------
#         # EXCEPTION
#         # ---------------------------------------

#         except Exception as e:

#             return Response(
#                 {
#                     "success": False,
#                     "message": "Property creation failed",
#                     "error": str(e)
#                 },
#                 status=status.HTTP_500_INTERNAL_SERVER_ERROR
#             )


class PropertyCreateAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):

        try:

            # ---------------------------------------
            # LOGGED-IN USER
            # ---------------------------------------

            logged_in_user = request.user

            # ---------------------------------------
            # SERIALIZER VALIDATION
            # ---------------------------------------

            serializer = PropertyCreateSerializer(
                data=request.data
            )

            if not serializer.is_valid():

                return Response(
                    {
                        "success": False,
                        "message": "Property creation failed",
                        "errors": serializer.errors
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ---------------------------------------
            # GET SOURCE
            # ---------------------------------------

            property_source = request.data.get(
                "source",
                "website"
            )

            property_source = str(
                property_source
            ).strip().lower()

            # ---------------------------------------
            # CURRENT TIME
            # ---------------------------------------

            current_time = timezone.now()

            # ---------------------------------------
            # SUBSCRIPTION LOGIC
            # ---------------------------------------

            if property_source == "admin":

                # =======================================
                # ADMIN PROPERTY
                # ALWAYS FREE
                # =======================================

                free_days = None
                free_expiry_date = None
                subscription_required = False
                subscription_active = True

            else:

                # =======================================
                # WEBSITE PROPERTY
                # =======================================

                # ---------------------------------------
                # CHECK USER'S PREVIOUS WEBSITE PROPERTY
                # ---------------------------------------

                previous_property_exists = Property.objects.filter(
                    agent=logged_in_user,
                    source="website"
                ).exists()

                # =======================================
                # FIRST PROPERTY
                # =======================================

                if not previous_property_exists:

                    # -----------------------------------
                    # GET DYNAMIC FREE DAYS
                    # -----------------------------------

                    setting = PropertySubscriptionSetting.objects.filter(
                        is_active=True
                    ).first()

                    if setting:
                        free_days = setting.free_days
                    else:
                        free_days = 15

                    # -----------------------------------
                    # FIRST PROPERTY FREE
                    # -----------------------------------

                    if free_days > 0:

                        free_expiry_date = (
                            current_time +
                            timedelta(days=free_days)
                        )

                        subscription_required = False
                        subscription_active = True

                    else:

                        free_expiry_date = None
                        subscription_required = True
                        subscription_active = False

                # =======================================
                # SECOND PROPERTY ONWARDS
                # =======================================

                else:

                    free_days = 0
                    free_expiry_date = None

                    subscription_required = True
                    subscription_active = False

            # ---------------------------------------
            # PROPERTY CREATE
            # ---------------------------------------

            property_obj = serializer.save(

                # Source
                source=property_source,

                # Logged-in user becomes agent
                agent=logged_in_user,

                # Subscription
                free_days=free_days,

                free_expiry_date=free_expiry_date,

                subscription_required=subscription_required,

                subscription_active=subscription_active
            )

            # ---------------------------------------
            # IMAGES UPLOAD TO S3
            # ---------------------------------------

            images = request.FILES.getlist("images")

            for image in images:

                image_url = upload_to_s3(
                    image,
                    f"properties/{property_obj.id}/images"
                )

                PropertyImage.objects.create(

                    property=property_obj,

                    image_s3_key=image_url,

                    image_type=request.data.get(
                        "image_type",
                        "other"
                    ),

                    caption=request.data.get(
                        "image_caption",
                        ""
                    ),

                    is_primary=False
                )

            # ---------------------------------------
            # VIDEOS UPLOAD TO S3
            # ---------------------------------------

            videos = request.FILES.getlist("videos")

            for video in videos:

                video_url = upload_to_s3(
                    video,
                    f"properties/{property_obj.id}/videos"
                )

                PropertyVideo.objects.create(
                    property=property_obj,
                    video_s3_key=video_url
                )

            # ---------------------------------------
            # RESPONSE SERIALIZER
            # ---------------------------------------

            response_serializer = PropertyDetailSerializer(
                property_obj,
                context={
                    "request": request
                }
            )

            # ---------------------------------------
            # SUCCESS RESPONSE
            # ---------------------------------------

            return Response(
                {
                    "success": True,

                    "message": "Property created successfully",

                    "property_id": property_obj.id,

                    "subscription": {

                        "source": property_obj.source,

                        "free_days": property_obj.free_days,

                        "free_expiry_date":
                            property_obj.free_expiry_date,

                        "subscription_required":
                            property_obj.subscription_required,

                        "subscription_active":
                            property_obj.subscription_active
                    },

                    "data": response_serializer.data
                },

                status=status.HTTP_201_CREATED
            )

        # ---------------------------------------
        # EXCEPTION
        # ---------------------------------------

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Property creation failed",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class PropertyUpdateAPIView(APIView):

    @transaction.atomic
    def post(self, request):

        try:
            # ---------------------------------------
            # PROPERTY ID
            # ---------------------------------------

            property_id = request.data.get("property_id")

            if not property_id:
                return Response(
                    {
                        "success": False,
                        "message": "property_id is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ---------------------------------------
            # GET PROPERTY
            # ---------------------------------------

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

            # ---------------------------------------
            # UPDATE PROPERTY
            # ---------------------------------------

            serializer = PropertyCreateSerializer(
                property_obj,
                data=request.data,
                partial=True
            )

            if not serializer.is_valid():

                return Response(
                    {
                        "success": False,
                        "message": "Property update failed",
                        "errors": serializer.errors
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            property_obj = serializer.save()

            # ---------------------------------------
            # NEW IMAGES UPLOAD TO S3
            # ---------------------------------------

            images = request.FILES.getlist("images")

            for image in images:

                image_url = upload_to_s3(
                    image,
                    f"properties/{property_obj.id}/images"
                )

                PropertyImage.objects.create(
                    property=property_obj,
                    image_s3_key=image_url,
                    image_type=request.data.get(
                        "image_type",
                        "other"
                    ),
                    caption=request.data.get(
                        "image_caption",
                        ""
                    ),
                    is_primary=False
                )

            # ---------------------------------------
            # NEW VIDEOS UPLOAD TO S3
            # ---------------------------------------

            videos = request.FILES.getlist("videos")

            for video in videos:

                video_url = upload_to_s3(
                    video,
                    f"properties/{property_obj.id}/videos"
                )

                PropertyVideo.objects.create(
                    property=property_obj,
                    video_s3_key=video_url,
                    title=request.data.get(
                        "video_title",
                        ""
                    ),
                    is_featured=False
                )

            # ---------------------------------------
            # RESPONSE
            # ---------------------------------------

            response_serializer = PropertyDetailSerializer(
                property_obj,
                context={
                    "request": request
                }
            )

            return Response(
                {
                    "success": True,
                    "message": "Property updated successfully",
                    "property_id": property_obj.id,
                    "data": response_serializer.data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Property update failed",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
            
class PropertyDetailAPIView(APIView):

    def post(self, request):

        slug = request.data.get("slug")

        if not slug:

            return Response(
                {
                    "status": False,
                    "message": "Property slug is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            property_obj = Property.objects.get(
                slug=slug
            )

        except Property.DoesNotExist:

            return Response(
                {
                    "status": False,
                    "message": "Property not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = ApprovedPropertyListSerializer(
            property_obj,
            context={
                "request": request
            }
        )

        return Response(
            {
                "status": True,
                "message": "Property details fetched successfully.",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
        
class PropertySubscriptionSettingCreateAPIView(APIView):

    def post(self, request):

        try:

            # ---------------------------------------
            # GET FREE DAYS
            # ---------------------------------------

            free_days = request.data.get("free_days")

            if free_days is None:
                return Response(
                    {
                        "success": False,
                        "message": "free_days is required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ---------------------------------------
            # VALIDATE FREE DAYS
            # ---------------------------------------

            try:
                free_days = int(free_days)
            except (ValueError, TypeError):

                return Response(
                    {
                        "success": False,
                        "message": "free_days must be a valid number"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if free_days <= 0:

                return Response(
                    {
                        "success": False,
                        "message": "free_days must be greater than 0"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ---------------------------------------
            # DEACTIVATE OLD SETTINGS
            # ---------------------------------------

            PropertySubscriptionSetting.objects.filter(
                is_active=True
            ).update(
                is_active=False
            )

            # ---------------------------------------
            # CREATE NEW SETTING
            # ---------------------------------------

            setting = PropertySubscriptionSetting.objects.create(
                free_days=free_days,
                is_active=True
            )

            # ---------------------------------------
            # RESPONSE
            # ---------------------------------------

            return Response(
                {
                    "success": True,
                    "message": "Property subscription setting created successfully",
                    "data": {
                        "id": setting.id,
                        "free_days": setting.free_days,
                        "is_active": setting.is_active,
                        "updated_at": setting.updated_at
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to create property subscription setting",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
class PropertyApproveAPIView(APIView):

    def post(self, request):

        property_id = request.data.get("id")

        if not property_id:
            return Response(
                {
                    "status": False,
                    "message": "Property ID is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            property_obj = Property.objects.get(id=property_id)

        except Property.DoesNotExist:
            return Response(
                {
                    "status": False,
                    "message": "Property not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # Already approved check
        if property_obj.status_approved:
            return Response(
                {
                    "status": False,
                    "message": "Property is already approved."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Approve property
        property_obj.status_approved = True
        property_obj.is_verified = True

        # Listing status active करा
        property_obj.status = Property.ListingStatus.ACTIVE

        property_obj.save(
            update_fields=[
                "status_approved",
                "is_verified",
                "status",
                "updated_at"
            ]
        )

        serializer = PropertyDetailSerializer(
            property_obj,
            context={"request": request}
        )

        return Response(
            {
                "status": True,
                "message": "Property approved successfully.",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
        
class ApprovedPropertyListAPIView(APIView):

    def post(self, request):

        try:
            now = timezone.now()

            properties = Property.objects.filter(
                status_approved=True,
                status=Property.ListingStatus.ACTIVE
            ).filter(
                Q(source="admin") |
                Q(subscription_active=True) |
                Q(
                    source="website",
                    free_expiry_date__gt=now,
                    subscription_active=False
                )
            ).order_by("-created_at")

            serializer = ApprovedPropertyListSerializer(
                properties,
                many=True,
                context={"request": request}
            )

            return Response(
                {
                    "status": True,
                    "message": "Approved properties fetched successfully.",
                    "count": properties.count(),
                    "data": serializer.data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "status": False,
                    "message": str(e),
                    "data": []
                },
                status=status.HTTP_400_BAD_REQUEST
            )
            
class PropertyListAPIView(APIView):

    def post(self, request):

        try:
            properties = Property.objects.all().order_by("-id")

            serializer = ApprovedPropertyListSerializer(
                properties,
                many=True,
                context={"request": request}
            )

            return Response(
                {
                    "status": True,
                    "message": "Properties fetched successfully.",
                    "count": properties.count(),
                    "data": serializer.data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "status": False,
                    "message": str(e),
                    "data": []
                },
                status=status.HTTP_400_BAD_REQUEST
            )            
            
class MyPropertyListAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        properties = Property.objects.filter(
            agent=request.user
        ).order_by("-id")

        serializer = PropertyDetailSerializer(
            properties,
            many=True,
            context={"request": request}
        )

        return Response(
            {
                "status": True,
                "message": "My properties fetched successfully.",
                "count": properties.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
            
class PropertyEnquiryCreateAPIView(APIView):

    def post(self, request):

        serializer = PropertyEnquiryCreateSerializer(
            data=request.data
        )

        if serializer.is_valid():

            enquiry = serializer.save()

            return Response(
                {
                    "success": True,
                    "message": "Property enquiry created successfully.",
                    "enquiry_id": enquiry.id,
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "success": False,
                "message": "Property enquiry creation failed.",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )   
        
        
              
            
class PropertyEnquiryReferralLinkAPIView(APIView):

    def post(self, request):

        slug = request.data.get("slug")
        referral_code = request.data.get("referral_code")

        # Validation
        if not slug:
            return Response(
                {
                    "status": False,
                    "message": "Property slug is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not referral_code:
            return Response(
                {
                    "status": False,
                    "message": "Referral code is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Property check
        try:
            property_obj = Property.objects.get(
                slug=slug
            )
        except Property.DoesNotExist:
            return Response(
                {
                    "status": False,
                    "message": "Property not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # Approved property only
        if property_obj.status_approve != "approved":
            return Response(
                {
                    "status": False,
                    "message": "Referral link is available only for approved property."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Save referral code
        property_obj.referral_code = referral_code
        property_obj.save(
            update_fields=["referral_code"]
        )

        # Generate referral link
        referral_link = (
            f"https://yourdomain.com/property/"
            f"{property_obj.slug}/"
            f"?ref={referral_code}"
        )

        return Response(
            {
                "status": True,
                "message": "Referral link generated successfully.",
                "data": {
                    "property_id": property_obj.id,
                    "slug": property_obj.slug,
                    "referral_code": referral_code,
                    "referral_link": referral_link
                }
            },
            status=status.HTTP_200_OK
        )   
        
class PropertyReferralLinkAPIView(APIView):


    def post(self, request):

        referral_code = request.data.get("referral_code")

        if not referral_code:
            return Response(
                {
                    "status": False,
                    "message": "Referral code is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            property_obj = Property.objects.get(
                referral_code=referral_code,
                status_approve="approved"
            )

        except Property.DoesNotExist:
            return Response(
                {
                    "status": False,
                    "message": "Property not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        referral_link = (
            f"https://qnxmartb2b.com/property-create"
            f"?ref={referral_code}"
        )

        return Response(
            {
                "status": True,
                "message": "Referral link generated successfully.",
                "data": {
            
                    "referral_code": referral_code,
                    "referral_link": referral_link
                }
            },
            status=status.HTTP_200_OK
        )
        

class PropertyEnquiryListAPIView(APIView):


    def post(self, request):

        enquiries = PropertyEnquiry.objects.all() \
            .select_related(
                "property",
                "assigned_channel_partner"
            ) \
            .order_by("-created_at")

        serializer = PropertyEnquiryCreateSerializer(
            enquiries,
            many=True,
            context={"request": request}
        )

        return Response(
            {
                "success": True,
                "message": "Property enquiries fetched successfully.",
                "count": enquiries.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )   
        



class PropertyEnquiryMultipalFilterListAPIView(APIView):

    def post(self, request):

        serializer = PropertyEnquiryFilterSerializer(
            data=request.data
        )

        serializer.is_valid(raise_exception=True)

        data = serializer.validated_data

        enquiries = PropertyEnquiry.objects.select_related(
            "property",
            "assigned_agent"
        ).all()

        if data.get("property"):
            enquiries = enquiries.filter(
                property_id=data["property"]
            )

        if data.get("assigned_agent"):
            enquiries = enquiries.filter(
                assigned_agent_id=data["assigned_agent"]
            )

        if data.get("customer_name"):
            enquiries = enquiries.filter(
                customer_name__icontains=data["customer_name"]
            )

        if data.get("status"):
            enquiries = enquiries.filter(
                status=data["status"]
            )

        if data.get("search"):
            enquiries = enquiries.filter(
                Q(customer_name__icontains=data["search"]) |
                Q(customer_mobile__icontains=data["search"])
            )

        response_serializer = PropertyEnquiryCreateSerializer(
            enquiries,
            many=True
        )

        return Response(
            {
                "status": True,
                "count": enquiries.count(),
                "data": response_serializer.data
            },
            status=status.HTTP_200_OK
        )                   
            
            
from decimal import Decimal            
class RealEstateChatbotAPIView(APIView):

    def post(self, request):

        data = request.data

        print("\n====================================")
        print("REAL ESTATE CHATBOT API")
        print("REQUEST:", data)
        print("====================================")

        purpose = data.get("purpose")
        property_type = data.get("property_type")
        city = data.get("city")
        location = data.get("location")
        bhk = data.get("bhk")
        min_budget = data.get("min_budget")
        max_budget = data.get("max_budget")

        # ==========================================
        # BASE QUERY
        # ==========================================

        queryset = Property.objects.filter(
            is_available=True
        )

        # ==========================================
        # PURPOSE
        # ==========================================

        if purpose:
            queryset = queryset.filter(
                transaction_type__iexact=purpose
            )

        # ==========================================
        # PROPERTY TYPE
        # ==========================================

        if property_type:
            queryset = queryset.filter(
                property_type__iexact=property_type
            )

        # ==========================================
        # CITY
        # ==========================================

        if city:
            queryset = queryset.filter(
                city__icontains=city
            )

        # ==========================================
        # LOCATION
        # ==========================================

        if location:

            queryset = queryset.filter(
                address__icontains=location
            ) | queryset.filter(
                landmark__icontains=location
            )

        # ==========================================
        # BHK
        # ==========================================

        if bhk:

            try:

                queryset = queryset.filter(
                    bedrooms=int(bhk)
                )

            except (ValueError, TypeError):

                pass

        # ==========================================
        # MIN BUDGET
        # ==========================================

        if min_budget:

            try:

                queryset = queryset.filter(
                    price__gte=Decimal(str(min_budget))
                )

            except:

                pass

        # ==========================================
        # MAX BUDGET
        # ==========================================

        if max_budget:

            try:

                queryset = queryset.filter(
                    price__lte=Decimal(str(max_budget))
                )

            except:

                pass

        # ==========================================
        # GET PROPERTIES
        # ==========================================

        properties = queryset.order_by(
            "-created_at"
        )[:10]

        # ==========================================
        # RESPONSE DATA
        # ==========================================

        property_list = []

        for property in properties:

            property_list.append({

                "id": property.id,

                "title": property.title,

                "slug": property.slug,

                "property_type":
                    property.property_type,

                "transaction_type":
                    property.transaction_type,

                "city":
                    property.city,

                "address":
                    property.address,

                "landmark":
                    property.landmark,

                "price":
                    str(property.price),

                "bedrooms":
                    property.bedrooms,

                "bathrooms":
                    property.bathrooms,

                "area":
                    str(property.area)
                    if property.area is not None
                    else None,

                "built_up_area":
                    str(property.built_up_area)
                    if property.built_up_area is not None
                    else None,

                "carpet_area":
                    str(property.carpet_area)
                    if property.carpet_area is not None
                    else None,

                "parking_count":
                    property.parking_count,

                "is_furnished":
                    property.is_furnished,

                "is_verified":
                    property.is_verified,

                "is_featured":
                    property.is_featured,

                "description":
                    property.description,

            })

        # ==========================================
        # MESSAGE
        # ==========================================

        if property_list:

            message = (
                f"{len(property_list)} properties "
                "found matching your requirement."
            )

        else:

            message = (
                "Sorry, no properties found "
                "matching your requirement."
            )

        # ==========================================
        # FINAL RESPONSE
        # ==========================================

        return Response({

            "success": True,

            "message": message,

            "count": len(property_list),

            "filters": {

                "purpose": purpose,

                "property_type": property_type,

                "city": city,

                "location": location,

                "bhk": bhk,

                "min_budget": min_budget,

                "max_budget": max_budget

            },

            "properties": property_list

        }, status=status.HTTP_200_OK)
        
        
        
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import ChatbotLead


class ChatbotLeadCreateAPIView(APIView):

    def post(self, request):

        data = request.data

        # ==========================================
        # GET DATA
        # ==========================================

        name = data.get("name")
        mobile = data.get("mobile")
        email = data.get("email")

        purpose = data.get("purpose")
        property_type = data.get("property_type")

        city = data.get("city")
        location = data.get("location")

        bhk = data.get("bhk")

        min_budget = data.get("min_budget")
        max_budget = data.get("max_budget")

        # ==========================================
        # REQUIRED VALIDATION
        # ==========================================

        if not name:
            return Response({
                "success": False,
                "message": "Name is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        if not mobile:
            return Response({
                "success": False,
                "message": "Mobile number is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        # ==========================================
        # CREATE LEAD
        # ==========================================

        try:

            lead = ChatbotLead.objects.create(

                name=name,

                mobile=mobile,

                email=email,

                purpose=purpose,

                property_type=property_type,

                city=city,

                location=location,

                bhk=bhk,

                min_budget=min_budget,

                max_budget=max_budget
            )

        except Exception as e:

            return Response({

                "success": False,

                "message":
                    "Unable to create lead.",

                "error": str(e)

            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # ==========================================
        # RESPONSE
        # ==========================================

        return Response({

            "success": True,

            "message":
                "Lead created successfully.",

            "lead_id":
                lead.id

        }, status=status.HTTP_201_CREATED)
        
        
  
        
        
        



import uuid
from decimal import Decimal, InvalidOperation

from django.db.models import Q

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import (
    Property,
    ChatSession,
    ChatMessage
)


class RealEstateChatAPIView(APIView):

    def post(self, request):

        message = str(
            request.data.get("message", "")
        ).strip()

        session_id = request.data.get("session_id")

        # ==================================================
        # VALIDATE MESSAGE
        # ==================================================

        if not message:

            return Response({

                "success": False,

                "message": "Message is required."

            }, status=status.HTTP_400_BAD_REQUEST)

        # ==================================================
        # GET / CREATE SESSION
        # ==================================================

        if session_id:

            try:

                session = ChatSession.objects.get(
                    session_id=session_id
                )

            except ChatSession.DoesNotExist:

                return Response({

                    "success": False,

                    "message": "Invalid session_id."

                }, status=status.HTTP_400_BAD_REQUEST)

        else:

            session_id = str(uuid.uuid4())

            session = ChatSession.objects.create(

                session_id=session_id,

                current_step="purpose"
            )

        # ==================================================
        # SAVE USER MESSAGE
        # ==================================================

        ChatMessage.objects.create(

            session=session,

            sender="user",

            message=message
        )

        msg = message.lower().strip()

        bot_message = ""

        options = []

        properties = []

        # ==================================================
        # STEP 1 - PURPOSE
        # ==================================================

        if session.current_step == "purpose":

            if msg in [
                "hi",
                "hello",
                "hey",
                "hii",
                "start"
            ]:

                bot_message = (
                    "Hello! 👋 Welcome to our Real Estate "
                    "assistant. Are you looking to Buy or Rent?"
                )

                options = [
                    "Buy",
                    "Rent"
                ]

            elif msg in [
                "buy",
                "purchase",
                "buy property"
            ]:

                session.purpose = "sale"

                session.current_step = "property_type"

                bot_message = (
                    "Great! What type of property "
                    "are you looking for?"
                )

                options = [
                    "Flat",
                    "Apartment",
                    "Bungalow",
                    "Villa",
                    "Land"
                ]

            elif msg in [
                "rent",
                "rental",
                "rent property"
            ]:

                session.purpose = "rent"

                session.current_step = "property_type"

                bot_message = (
                    "Great! What type of property "
                    "do you want to rent?"
                )

                options = [
                    "Flat",
                    "Apartment",
                    "Bungalow",
                    "Villa"
                ]

            else:

                bot_message = (
                    "Are you looking to Buy or Rent?"
                )

                options = [
                    "Buy",
                    "Rent"
                ]

        # ==================================================
        # STEP 2 - PROPERTY TYPE
        # ==================================================

        elif session.current_step == "property_type":

            property_type_map = {

                "flat": "flat",

                "apartment": "apartment",

                "bungalow": "bungalow",

                "villa": "villa",

                "land": "land",

                "plot": "land"
            }

            selected_type = property_type_map.get(msg)

            if selected_type:

                session.property_type = selected_type

                session.current_step = "city"

                bot_message = (
                    "Which city are you looking "
                    "for the property in?"
                )

            else:

                bot_message = (
                    "Please select a valid property type."
                )

                options = [
                    "Flat",
                    "Apartment",
                    "Bungalow",
                    "Villa",
                    "Land"
                ]

        # ==================================================
        # STEP 3 - CITY
        # ==================================================

        elif session.current_step == "city":

            session.city = message

            session.current_step = "location"

            bot_message = (
                "Which area or location are you "
                "looking for?"
            )

        # ==================================================
        # STEP 4 - LOCATION
        # ==================================================

        elif session.current_step == "location":

            session.location = message

            session.current_step = "bhk"

            bot_message = (
                "How many BHK do you need?"
            )

            options = [
                "1 BHK",
                "2 BHK",
                "3 BHK",
                "4 BHK"
            ]

        # ==================================================
        # STEP 5 - BHK
        # ==================================================

        elif session.current_step == "bhk":

            try:

                bhk_text = (
                    msg
                    .replace("bhk", "")
                    .strip()
                )

                bhk = int(bhk_text)

                session.bhk = bhk

                session.current_step = "budget"

                bot_message = (
                    "What is your budget?\n\n"
                    "Example: 50 lakh\n"
                    "or\n"
                    "30-50 lakh"
                )

            except (ValueError, TypeError):

                bot_message = (
                    "Please enter a valid BHK."
                )

                options = [
                    "1 BHK",
                    "2 BHK",
                    "3 BHK",
                    "4 BHK"
                ]

        # ==================================================
        # STEP 6 - BUDGET
        # ==================================================

        elif session.current_step == "budget":

            try:

                budget_text = (
                    msg
                    .replace("₹", "")
                    .replace(",", "")
                    .replace("lakh", "")
                    .replace("lakhs", "")
                    .strip()
                )

                # ------------------------------------------
                # 30-50
                # ------------------------------------------

                if "-" in budget_text:

                    parts = budget_text.split("-")

                    if len(parts) != 2:

                        raise ValueError(
                            "Invalid budget format"
                        )

                    min_budget = (
                        Decimal(
                            parts[0].strip()
                        ) * 100000
                    )

                    max_budget = (
                        Decimal(
                            parts[1].strip()
                        ) * 100000
                    )

                # ------------------------------------------
                # 50
                # ------------------------------------------

                else:

                    max_budget = (
                        Decimal(
                            budget_text
                        ) * 100000
                    )

                    min_budget = Decimal("0")

                session.min_budget = min_budget

                session.max_budget = max_budget

                # ==========================================
                # PROPERTY SEARCH
                # ==========================================

                queryset = Property.objects.filter(

                    is_available=True,

                    status="active",

                    status_approve="approved"

                )

                # ==========================================
                # TRANSACTION TYPE
                # ==========================================

                if session.purpose:

                    queryset = queryset.filter(

                        transaction_type__iexact=
                        session.purpose

                    )

                # ==========================================
                # PROPERTY TYPE
                # ==========================================

                if session.property_type:

                    queryset = queryset.filter(

                        property_type__iexact=
                        session.property_type

                    )

                # ==========================================
                # CITY
                # ==========================================

                if session.city:

                    queryset = queryset.filter(

                        city__icontains=
                        session.city

                    )

                # ==========================================
                # LOCATION
                # ==========================================

                if session.location:

                    queryset = queryset.filter(

                        Q(
                            area__icontains=
                            session.location
                        )
                        |
                        Q(
                            address__icontains=
                            session.location
                        )
                        |
                        Q(
                            landmark__icontains=
                            session.location
                        )
                        |
                        Q(
                            pincode__icontains=
                            session.location
                        )

                    )

                # ==========================================
                # BHK
                # ==========================================

                if session.bhk:

                    queryset = queryset.filter(

                        bedrooms=session.bhk

                    )

                # ==========================================
                # PRICE
                # ==========================================

                queryset = queryset.filter(

                    price__gte=
                    session.min_budget,

                    price__lte=
                    session.max_budget

                )

                # ==========================================
                # LIMIT
                # ==========================================

                queryset = queryset.order_by(

                    "-is_featured",

                    "-is_verified",

                    "-created_at"

                )[:10]

                # ==========================================
                # PROPERTY RESPONSE
                # ==========================================

                for property in queryset:

                    properties.append({

                        "id":
                            property.id,

                        "title":
                            property.title,

                        "slug":
                            property.slug,

                        "description":
                            property.description,

                        "property_type":
                            property.property_type,

                        "transaction_type":
                            property.transaction_type,

                        "status":
                            property.status,

                        "price":
                            str(property.price),

                        "price_per_sqft":
                            str(property.price_per_sqft)
                            if property.price_per_sqft
                            else None,

                        "total_area":
                            str(property.total_area)
                            if property.total_area
                            else None,

                        "carpet_area":
                            str(property.carpet_area)
                            if property.carpet_area
                            else None,

                        "built_up_area":
                            str(property.built_up_area)
                            if property.built_up_area
                            else None,

                        "bedrooms":
                            property.bedrooms,

                        "bathrooms":
                            property.bathrooms,

                        "balconies":
                            property.balconies,

                        "kitchens":
                            property.kitchens,

                        "parking_count":
                            property.parking_count,

                        "parking_type":
                            property.parking_type,

                        "city":
                            property.city,

                        "area":
                            property.area,

                        "address":
                            property.address,

                        "landmark":
                            property.landmark,

                        "pincode":
                            property.pincode,

                        "latitude":
                            str(property.latitude)
                            if property.latitude
                            else None,

                        "longitude":
                            str(property.longitude)
                            if property.longitude
                            else None,

                        "features":
                            property.features,

                        "owner_name":
                            property.owner_name,

                        "owner_contact":
                            property.owner_contact,

                        "owner_email":
                            property.owner_email,

                        "is_featured":
                            property.is_featured,

                        "is_verified":
                            property.is_verified,

                        "is_furnished":
                            property.is_furnished,

                        "is_negotiable":
                            property.is_negotiable,

                        "is_available":
                            property.is_available

                    })

                # ==========================================
                # MESSAGE
                # ==========================================

                if properties:

                    bot_message = (
                        f"Great! I found "
                        f"{len(properties)} properties "
                        "matching your requirements. 🏠"
                    )

                else:

                    bot_message = (
                        "Sorry, I couldn't find any "
                        "properties matching your requirements. "
                        "Would you like to try another location "
                        "or budget?"
                    )

                session.is_completed = True

                session.current_step = "completed"

            except (
                ValueError,
                InvalidOperation,
                TypeError
            ):

                bot_message = (
                    "Please enter your budget correctly.\n\n"
                    "Example: 50 lakh\n"
                    "or\n"
                    "30-50 lakh"
                )

        # ==================================================
        # COMPLETED
        # ==================================================

        elif session.current_step == "completed":

            bot_message = (
                "Your property search is already completed. "
                "Would you like to start a new search?"
            )

            options = [
                "New Search"
            ]

        # ==================================================
        # SAVE SESSION
        # ==================================================

        session.save()

        # ==================================================
        # SAVE BOT MESSAGE
        # ==================================================

        ChatMessage.objects.create(

            session=session,

            sender="bot",

            message=bot_message

        )

        # ==================================================
        # FINAL RESPONSE
        # ==================================================

        return Response({

            "success": True,

            "session_id":
                session.session_id,

            "current_step":
                session.current_step,

            "message":
                bot_message,

            "options":
                options,

            "properties":
                properties

        }, status=status.HTTP_200_OK)
        
        
        


class RealEstateChannelPartnerCreateAPIView(APIView):
    def post(self, request):
        serializer = RealEstateChannelPartnerSerializer(
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
        cp = serializer.save()
        return Response(
            {
                "success": True,
                "message": "Channel Partner created successfully.",
                "data": RealEstateChannelPartnerSerializer(cp).data
            },
            status=status.HTTP_201_CREATED
        )
        
        
class RealEstateChannelPartnerListAPIView(APIView):

    def post(self, request):

        channel_partners = RealEstateChannelPartner.objects.all().order_by("-id")

        serializer = RealEstateChannelPartnerSerializer(
            channel_partners,
            many=True
        )

        return Response(
            {
                "success": True,
                "message": "Channel Partners fetched successfully.",
                "count": channel_partners.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
                
        
from decimal import Decimal, ROUND_HALF_UP

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import (
    Property,
    RealEstateChannelPartner,
    RealEstatePropertyCommission
)

from .serializers import (
    RealEstatePropertyCommissionSerializer
)


class RealEstatePropertyCommissionCreateAPIView(APIView):

    def post(self, request):

        # =====================================================
        # GET REQUEST DATA
        # =====================================================

        property_id = request.data.get('property')
        channel_partner_id = request.data.get('channel_partner')
        sale_price = request.data.get('sale_price')
        business_partner_percentage = request.data.get(
            'business_partner_percentage'
        )

        # =====================================================
        # VALIDATION
        # =====================================================

        if not property_id:
            return Response(
                {
                    "success": False,
                    "message": "Property ID is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not channel_partner_id:
            return Response(
                {
                    "success": False,
                    "message": "Channel Partner ID is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if sale_price is None:
            return Response(
                {
                    "success": False,
                    "message": "Sale price is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if business_partner_percentage is None:
            return Response(
                {
                    "success": False,
                    "message": (
                        "Business Partner percentage is required."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # GET PROPERTY
        # =====================================================

        try:
            property_obj = Property.objects.get(
                id=property_id
            )

        except Property.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Property not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # =====================================================
        # GET CHANNEL PARTNER
        # =====================================================

        try:
            cp = RealEstateChannelPartner.objects.get(
                id=channel_partner_id
            )

        except RealEstateChannelPartner.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Channel Partner not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # =====================================================
        # CHECK CP STATUS
        # =====================================================

        if cp.status != 'active':
            return Response(
                {
                    "success": False,
                    "message": "Channel Partner is not active."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # DECIMAL CONVERSION
        # =====================================================

        try:

            sale_price = Decimal(
                str(sale_price)
            )

            business_partner_percentage = Decimal(
                str(business_partner_percentage)
            )

        except Exception:

            return Response(
                {
                    "success": False,
                    "message": "Invalid amount or percentage."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # SALE PRICE VALIDATION
        # =====================================================

        if sale_price <= 0:
            return Response(
                {
                    "success": False,
                    "message": (
                        "Sale price must be greater than 0."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # BUSINESS PARTNER % VALIDATION
        # =====================================================

        if (
            business_partner_percentage < 0
            or business_partner_percentage > 100
        ):
            return Response(
                {
                    "success": False,
                    "message": (
                        "Business Partner percentage "
                        "must be between 0 and 100."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # GET CP COMMISSION %
        # From CP Master
        # =====================================================

        cp_commission_percentage = Decimal(
            str(cp.commission_percentage)
        )

        # =====================================================
        # CALCULATE CP COMMISSION
        # =====================================================

        cp_commission_amount = (
            sale_price *
            cp_commission_percentage /
            Decimal('100')
        )

        # =====================================================
        # CALCULATE BUSINESS PARTNER AMOUNT
        #
        # BP percentage is calculated on CP commission amount
        # =====================================================

        business_partner_amount = (
            cp_commission_amount *
            business_partner_percentage /
            Decimal('100')
        )

        # =====================================================
        # CP FINAL AMOUNT
        # =====================================================

        cp_final_amount = (
            cp_commission_amount -
            business_partner_amount
        )

        # =====================================================
        # ROUND AMOUNTS
        # =====================================================

        cp_commission_amount = cp_commission_amount.quantize(
            Decimal('0.01'),
            rounding=ROUND_HALF_UP
        )

        business_partner_amount = business_partner_amount.quantize(
            Decimal('0.01'),
            rounding=ROUND_HALF_UP
        )

        cp_final_amount = cp_final_amount.quantize(
            Decimal('0.01'),
            rounding=ROUND_HALF_UP
        )

        # =====================================================
        # CREATE OR UPDATE
        #
        # Same Property + Same CP
        # => Same ID
        # =====================================================

        commission, created = (
            RealEstatePropertyCommission.objects.update_or_create(

                property=property_obj,

                channel_partner=cp,

                defaults={

                    'sale_price': sale_price,

                    'cp_commission_percentage': (
                        cp_commission_percentage
                    ),

                    'cp_commission_amount': (
                        cp_commission_amount
                    ),

                    'business_partner_percentage': (
                        business_partner_percentage
                    ),

                    'business_partner_amount': (
                        business_partner_amount
                    ),

                    'cp_final_amount': (
                        cp_final_amount
                    ),
                }
            )
        )

        # =====================================================
        # SERIALIZER
        # =====================================================

        serializer = RealEstatePropertyCommissionSerializer(
            commission
        )

        # =====================================================
        # MESSAGE
        # =====================================================

        if created:

            message = (
                "Property commission created successfully."
            )

        else:

            message = (
                "Property commission updated successfully."
            )

        # =====================================================
        # RESPONSE
        # =====================================================

        return Response(
            {
                "success": True,
                "created": created,
                "message": message,

                "data": serializer.data
            },

            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            )
        )        
class MyEnquiryMarketingPartnerListAPIView(APIView):

    def post(self, request):

        enquiry_id = request.data.get("enquiry_id")

        if not enquiry_id:
            return Response({
                "status": False,
                "message": "enquiry_id is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get enquiry
        try:
            enquiry = PropertyEnquiry.objects.select_related(
                "property",
                "property__marketing_partner"
            ).get(id=enquiry_id)

        except PropertyEnquiry.DoesNotExist:
            return Response({
                "status": False,
                "message": "Enquiry not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # Property चा Marketing Partner
        property_partner = enquiry.property.marketing_partner

        # Approved partners
        partners = list(
            MarketingPartner.objects.filter(
                status="approved"
            ).order_by("-created_at")
        )

        # Property चा partner असेल तर त्याला first position ला आणा
        if property_partner:

            partners = sorted(
                partners,
                key=lambda partner: partner.id != property_partner.id
            )

        serializer = MarketingPartnerSerializer(
            partners,
            many=True,
            context={"request": request}
        )

        return Response({
            "status": True,
            "message": "Approved marketing partners fetched successfully",
            "count": len(partners),
            "data": serializer.data
        }, status=status.HTTP_200_OK)     
        
class AssignPropertyEnquiryAPIView(APIView):

    def post(self, request):

        enquiry_id = request.data.get("enquiry_id")
        channel_partner_id = request.data.get("channel_partner_id")

        # -----------------------------------------
        # VALIDATION
        # -----------------------------------------

        if not enquiry_id:
            return Response(
                {
                    "success": False,
                    "message": "enquiry_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not channel_partner_id:
            return Response(
                {
                    "success": False,
                    "message": "channel_partner_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # -----------------------------------------
        # GET ENQUIRY
        # -----------------------------------------

        try:
            enquiry = PropertyEnquiry.objects.get(
                id=enquiry_id
            )

        except PropertyEnquiry.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Property enquiry not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # -----------------------------------------
        # GET MARKETING PARTNER
        # ACTIVE LOGIC REMOVED
        # -----------------------------------------

        try:
            channel_partner = MarketingPartner.objects.get(
                id=channel_partner_id
            )

        except MarketingPartner.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Channel partner not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # -----------------------------------------
        # ASSIGN
        # -----------------------------------------

        enquiry.assigned_channel_partner = channel_partner
        enquiry.assigned_at = timezone.now()

        # "assigned" is NOT present in your Status choices
        enquiry.status = PropertyEnquiry.Status.CONTACTED

        enquiry.save(
            update_fields=[
                "assigned_channel_partner",
                "assigned_at",
                "status",
                "updated_at"
            ]
        )

        # -----------------------------------------
        # RESPONSE
        # -----------------------------------------

        return Response(
            {
                "success": True,
                "message": "Property enquiry assigned successfully.",
                "data": {
                    "enquiry_id": enquiry.id,
                    "channel_partner_id": channel_partner.id,
                    "status": enquiry.status,
                    "assigned_at": enquiry.assigned_at
                }
            },
            status=status.HTTP_200_OK
        )
        
class ChannelPartnerEnquiryListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:
            channel_partner = MarketingPartner.objects.filter(
                user=request.user
            ).first()

            if not channel_partner:
                return Response(
                    {
                        "success": False,
                        "message": "Channel partner not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            enquiries = PropertyEnquiry.objects.filter(
                assigned_channel_partner=channel_partner
            ).select_related(
                "property"
            ).order_by("-created_at")

            serializer = PropertyEnquiryCreateSerializer(
                enquiries,
                many=True,
                context={"request": request}
            )

            return Response(
                {
                    "success": True,
                    "message": "Channel partner enquiries fetched successfully.",

                    "channel_partner": {
                        "id": channel_partner.id,
                        "name": channel_partner.full_name,
                        "cp_code": channel_partner.referral_code
                    },

                    "count": enquiries.count(),
                    "data": serializer.data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
            
            
class SchedulePropertyMeetingAPIView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        # ==================================================
        # 1. Get enquiry_id
        # ==================================================

        enquiry_id = request.data.get("enquiry_id")

        if not enquiry_id:
            return Response(
                {
                    "success": False,
                    "error": "enquiry_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==================================================
        # 2. Get Active Marketing Partner
        # ==================================================

        try:
            marketing_partner = MarketingPartner.objects.get(
                user=request.user,
                status="approved"
            )

        except MarketingPartner.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "error": "Active Marketing Partner profile not found."
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # ==================================================
        # 3. Get Property Enquiry
        # ==================================================

        try:

            enquiry = (
                PropertyEnquiry.objects
                .select_related(
                    "property",
                    "assigned_channel_partner"
                )
                .get(id=enquiry_id)
            )

        except PropertyEnquiry.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "error": "Property enquiry not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # ==================================================
        # 4. Check Enquiry Assignment
        # ==================================================

        if (
            enquiry.assigned_channel_partner_id
            != marketing_partner.id
        ):

            return Response(
                {
                    "success": False,
                    "error": "This enquiry is not assigned to you."
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # ==================================================
        # 5. Get Meeting Details
        # ==================================================

        meeting_date = request.data.get("meeting_date")
        meeting_time = request.data.get("meeting_time")
        meeting_location = request.data.get("meeting_location")
        meeting_notes = request.data.get("meeting_notes")

        # ==================================================
        # 6. Required Validation
        # ==================================================

        if not meeting_date:

            return Response(
                {
                    "success": False,
                    "error": "meeting_date is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not meeting_time:

            return Response(
                {
                    "success": False,
                    "error": "meeting_time is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==================================================
        # 7. Validate Date & Time
        # ==================================================

        try:

            meeting_datetime = datetime.strptime(
                f"{meeting_date} {meeting_time}",
                "%Y-%m-%d %H:%M"
            )

        except ValueError:

            return Response(
                {
                    "success": False,
                    "error": (
                        "Invalid meeting date/time format. "
                        "Use meeting_date: YYYY-MM-DD "
                        "and meeting_time: HH:MM."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==================================================
        # 8. Prevent Past Meeting
        # ==================================================

        current_datetime = timezone.localtime().replace(
            tzinfo=None
        )

        if meeting_datetime < current_datetime:

            return Response(
                {
                    "success": False,
                    "error": (
                        "Meeting date and time "
                        "cannot be in the past."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==================================================
        # 9. Check Customer Mobile
        # ==================================================

        if not enquiry.customer_mobile:

            return Response(
                {
                    "success": False,
                    "error": (
                        "Customer mobile number "
                        "is not available."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==================================================
        # 10. Save Meeting
        # ==================================================

        enquiry.meeting_date = meeting_date
        enquiry.meeting_time = meeting_time
        enquiry.meeting_location = (
            meeting_location or "Property Site"
        )
        enquiry.meeting_notes = meeting_notes

        enquiry.meeting_scheduled_at = timezone.now()

        # Automatically change status
        enquiry.status = PropertyEnquiry.Status.SITE_VISIT

        enquiry.save(
            update_fields=[
                "meeting_date",
                "meeting_time",
                "meeting_location",
                "meeting_notes",
                "meeting_scheduled_at",
                "status",
            ]
        )

        # ==================================================
        # 11. Send WhatsApp Message using WATI
        # ==================================================

        whatsapp_result = None

        try:

            whatsapp_result = send_whatsapp_meeting_message(

                customer_phone=enquiry.customer_mobile,

                customer_name=(
                    enquiry.customer_name or ""
                ),

                property_name=(
                    enquiry.property.title
                    if enquiry.property
                    else ""
                ),

                meeting_date=str(
                    enquiry.meeting_date
                ),

                meeting_time=str(
                    enquiry.meeting_time
                ),

                meeting_location=(
                    enquiry.meeting_location
                    or "Property Site"
                )
            )

        except Exception as e:

            whatsapp_result = {
                "success": False,
                "error": str(e)
            }

        # ==================================================
        # 12. Final Response
        # ==================================================

        return Response(
            {
                "success": True,

                "message": (
                    "Meeting scheduled successfully."
                ),

                "meeting": {

                    "enquiry_id": enquiry.id,

                    "customer": {
                        "name": enquiry.customer_name,
                        "email": enquiry.customer_email,
                        "mobile": enquiry.customer_mobile,
                    },

                    "property": {
                        "id": (
                            enquiry.property.id
                            if enquiry.property
                            else None
                        ),

                        "title": (
                            enquiry.property.title
                            if enquiry.property
                            else None
                        ),
                    },

                    "meeting": {

                        "date": enquiry.meeting_date,

                        "time": enquiry.meeting_time,

                        "location": (
                            enquiry.meeting_location
                        ),

                        "notes": (
                            enquiry.meeting_notes
                        ),
                    },

                    "status": enquiry.status,

                    "scheduled_at": (
                        enquiry.meeting_scheduled_at
                    ),
                },

                "whatsapp": whatsapp_result,
            },

            status=status.HTTP_200_OK
        )
        
class UpdatePropertyMeetingStatusAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        enquiry_id = request.data.get("enquiry_id")
        meeting_status = request.data.get("meeting_status")
        meeting_outcome = request.data.get("meeting_outcome")
        meeting_feedback = request.data.get("meeting_feedback")
        next_followup_date = request.data.get("next_followup_date")

        if not enquiry_id:
            return Response(
                {
                    "success": False,
                    "message": "enquiry_id is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not meeting_status:
            return Response(
                {
                    "success": False,
                    "message": "meeting_status is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Logged-in Marketing Partner
        try:
            marketing_partner = MarketingPartner.objects.get(
                user=request.user,
                status="active"
            )
        except MarketingPartner.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Active Marketing Partner not found"
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # Get enquiry
        try:
            enquiry = PropertyEnquiry.objects.select_related(
                "property",
                "assigned_channel_partner"
            ).get(id=enquiry_id)
        except PropertyEnquiry.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Property enquiry not found"
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # Check assignment
        if enquiry.assigned_channel_partner_id != marketing_partner.id:
            return Response(
                {
                    "success": False,
                    "message": "This enquiry is not assigned to you"
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # Allowed meeting statuses
        allowed_statuses = [
            "scheduled",
            "confirmed",
            "rescheduled",
            "completed",
            "customer_not_attended",
            "partner_not_attended",
            "cancelled",
        ]

        if meeting_status not in allowed_statuses:
            return Response(
                {
                    "success": False,
                    "message": "Invalid meeting_status",
                    "allowed_statuses": allowed_statuses
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update meeting information
        enquiry.meeting_status = meeting_status

        if meeting_outcome is not None:
            enquiry.meeting_outcome = meeting_outcome

        if meeting_feedback is not None:
            enquiry.meeting_feedback = meeting_feedback

        if next_followup_date:
            enquiry.next_followup_date = next_followup_date

        # Update enquiry main status
        if meeting_status == "completed":
            enquiry.status = PropertyEnquiry.Status.SITE_VISIT

        elif meeting_status == "cancelled":
            enquiry.status = PropertyEnquiry.Status.CONTACTED

        elif meeting_status == "customer_not_attended":
            enquiry.status = PropertyEnquiry.Status.CONTACTED

        elif meeting_status == "partner_not_attended":
            enquiry.status = PropertyEnquiry.Status.CONTACTED

        elif meeting_status in ["scheduled", "confirmed", "rescheduled"]:
            enquiry.status = PropertyEnquiry.Status.SITE_VISIT

        enquiry.updated_at = timezone.now()
        enquiry.save()

        return Response(
            {
                "success": True,
                "message": "Meeting status updated successfully",
                "data": {
                    "enquiry_id": enquiry.id,
                    "meeting_status": enquiry.meeting_status,
                    "meeting_outcome": enquiry.meeting_outcome,
                    "meeting_feedback": enquiry.meeting_feedback,
                    "next_followup_date": enquiry.next_followup_date,
                    "enquiry_status": enquiry.status,
                    "updated_at": enquiry.updated_at,
                }
            },
            status=status.HTTP_200_OK
        )        
        
        
        
        