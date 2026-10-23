import re
from django.db import transaction
from django.utils import timezone
from django.db.models import Prefetch
from rest_framework.views import APIView
from rest_framework.response import Response
from decimal import Decimal, InvalidOperation
from rest_framework import status
import json
from .models import BazaarSettings
from .models import BazaarEnquiry
from .whatsapp import send_bazaar_enquiry_message
from django.db.models import Max
from rest_framework.permissions import IsAuthenticated
from .s3_upload import upload_bazaar_listing_image,get_bazaar_image_url, delete_bazaar_listing_image

from .models import (
    BazaarCategory,
    BazaarSubCategory,
    BazaarAttribute,
    BazaarListing,
    BazaarListingImage,

    BazaarCommunicationPlan,
    BazaarCommunicationSettings,
    BazaarCommunicationSubscription,

    BazaarChat,
    BazaarChatMessage,
    BazaarListing,
    BazaarCommunicationSettings,
)

from .serializers import (
    BazaarCategorySerializer,
    BazaarListingSerializer,
    BazaarPlanSerializer,
    BazaarPricingSerializer,   
    BazaarCategoryCreateSerializer,
    BazaarSubCategoryCreateSerializer,
    BazaarSubCategoryListSerializer,
    BazaarAttributeCreateSerializer,
    BazaarListingCreateSerializer,
    BazaarListingListSerializer,
    BazaarAttributeSerializer,
    BazaarListingUpdateSerializer,

    BazaarCommunicationPlanSerializer,
    BazaarCommunicationSettingsSerializer,
    BazaarCommunicationSubscriptionSerializer,

    BazaarChatCreateSerializer,
    BazaarChatSerializer,
    BazaarChatMessageCreateSerializer,
    BazaarChatMessageSerializer,
)

from .services import (
    get_bazaar_settings,
    get_user_listing_count,
    activate_first_listing,
)

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import BazaarCategory
from .serializers import BazaarCategoryCreateSerializer


from django.shortcuts import get_object_or_404

from .bazaar_comm_services.communication_access import (
    BazaarCommunicationAccessService,
)

from django.contrib.auth import get_user_model
from django.db.models import Q

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from payment.models import BazaarCommunicationPayment

from .bazaar_comm_services.communication_access import (
    BazaarCommunicationAccessService,
)

User = get_user_model()









class BazaarCategoryCreateAPIView(APIView):

    def post(self, request):

        try:

            serializer = BazaarCategoryCreateSerializer(
                data=request.data
            )

            print("STEP 1 - SERIALIZER CREATED")

            if not serializer.is_valid():

                print("STEP 2 - VALIDATION ERROR")
                print(serializer.errors)

                return Response(
                    {
                        "success": False,
                        "message": "Category creation failed",
                        "errors": serializer.errors
                    },
                    status=400
                )

            print("STEP 3 - VALIDATION SUCCESS")

            category = serializer.save()

            print("STEP 4 - CATEGORY SAVED")
            print("CATEGORY ID:", category.id)

            data = {
                "success": True,
                "message": "Category created successfully",
                "id": category.id
            }

            print("STEP 5 - RESPONSE DATA CREATED")
            print(data)

            return Response(data, status=201)

        except Exception as e:

            import traceback

            print("========== CATEGORY ERROR ==========")
            print(str(e))
            traceback.print_exc()
            print("====================================")

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=500
            )
class BazaarCategoryListAPIView(APIView):

    def post(self, request):

        categories = BazaarCategory.objects.filter(
            is_active=True
        ).prefetch_related(
            "subcategories",
            "attributes"
        )

        serializer = BazaarCategorySerializer(
            categories,
            many=True
        )

        return Response({
            "success": True,
            "data": serializer.data
        })
        
        
        
from django.db import transaction
from django.utils import timezone
from datetime import timedelta

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated


class BazaarListingCreateAPIView(APIView):

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):

        try:

            print("====================================")
            print("BAZAAR LISTING CREATE")
            print("USER:", request.user)
            print("DATA:", request.data)
            print("FILES:", request.FILES)
            print("====================================")

            # ==================================================
            # GET BAZAAR SETTINGS
            # ==================================================

            settings_obj = BazaarSettings.objects.filter(
                is_active=True
            ).order_by("-id").first()

            if not settings_obj:

                return Response(
                    {
                        "success": False,
                        "message": "Bazaar settings are not configured."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==================================================
            # CHECK USER'S EXISTING LISTINGS
            # ==================================================

            existing_listing_count = BazaarListing.objects.filter(
                user=request.user
            ).count()

            is_first_listing = existing_listing_count == 0

            # ==================================================
            # FIRST LISTING FREE
            # ==================================================

            if (
                is_first_listing
                and settings_obj.first_listing_free
            ):

                free_period_days = settings_obj.free_listing_days

                active_from = timezone.now()

                expires_at = (
                    active_from
                    + timedelta(days=free_period_days)
                )

                listing_status = "active"

                subscription_required = False

            # ==================================================
            # SECOND / NEXT LISTING
            # ==================================================

            else:

                free_period_days = 0

                active_from = None

                expires_at = None

                # Subscription required
                subscription_required = True

                # Listing pending until subscription/payment
                listing_status = "pending"

            # ==================================================
            # SERIALIZER
            # ==================================================

            serializer = BazaarListingCreateSerializer(
                data=request.data
            )

            if not serializer.is_valid():

                return Response(
                    {
                        "success": False,
                        "message": "Listing creation failed.",
                        "errors": serializer.errors
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==================================================
            # CREATE LISTING
            # ==================================================

            listing = serializer.save(
                user=request.user,
                status=listing_status,
                is_first_listing=is_first_listing,
                free_period_days=free_period_days,
                active_from=active_from,
                expires_at=expires_at
            )

            # ==================================================
            # GET MULTIPLE IMAGES
            # ==================================================

            images = request.FILES.getlist("images")

            image_data = []

            # ==================================================
            # S3 IMAGE UPLOAD
            # ==================================================

            for index, image in enumerate(images):

                print(
                    f"Uploading image {index + 1}:",
                    image.name
                )

                s3_key = upload_bazaar_listing_image(
                    image,
                    listing.id
                )

                listing_image = BazaarListingImage.objects.create(
                    listing=listing,
                    image_s3_key=s3_key,
                    is_primary=(index == 0),
                    sort_order=index
                )

                image_data.append(
                    {
                        "id": listing_image.id,

                        "image_s3_key": (
                            listing_image.image_s3_key
                        ),

                        "image_url": get_bazaar_image_url(
                            listing_image.image_s3_key
                        ),

                        "is_primary": (
                            listing_image.is_primary
                        ),

                        "sort_order": (
                            listing_image.sort_order
                        )
                    }
                )

            # ==================================================
            # SUCCESS RESPONSE
            # ==================================================

            return Response(
                {
                    "success": True,

                    "message": (
                        "First listing created successfully "
                        "and is free for "
                        f"{free_period_days} days."
                        if is_first_listing
                        else
                        "Listing created successfully. "
                        "Subscription is required to activate this listing."
                    ),

                    "data": {

                        "id": listing.id,

                        "user_id": listing.user.id,

                        # ----------------------------------
                        # CATEGORY
                        # ----------------------------------

                        "category_id": listing.category.id,

                        "category_name": listing.category.name,

                        # ----------------------------------
                        # SUBCATEGORY
                        # ----------------------------------

                        "subcategory_id": (
                            listing.subcategory.id
                            if listing.subcategory
                            else None
                        ),

                        "subcategory_name": (
                            listing.subcategory.name
                            if listing.subcategory
                            else None
                        ),

                        # ----------------------------------
                        # BASIC DETAILS
                        # ----------------------------------

                        "title": listing.title,

                        "description": listing.description,

                        "price": float(listing.price),

                        "is_negotiable": listing.is_negotiable,

                        "condition": listing.condition,

                        "seller_type": listing.seller_type,

                        # ----------------------------------
                        # LOCATION
                        # ----------------------------------

                        "city": listing.city,

                        "area": listing.area,

                        "address": listing.address,

                        "pincode": listing.pincode,

                        "latitude": (
                            float(listing.latitude)
                            if listing.latitude is not None
                            else None
                        ),

                        "longitude": (
                            float(listing.longitude)
                            if listing.longitude is not None
                            else None
                        ),

                        # ----------------------------------
                        # ATTRIBUTES
                        # ----------------------------------

                        "attributes": listing.attributes,

                        # ----------------------------------
                        # STATUS
                        # ----------------------------------

                        "status": listing.status,

                        "subscription_required": (
                            subscription_required
                        ),

                        # ----------------------------------
                        # FEATURED
                        # ----------------------------------

                        "is_featured": listing.is_featured,

                        # ----------------------------------
                        # FIRST LISTING
                        # ----------------------------------

                        "is_first_listing": (
                            listing.is_first_listing
                        ),

                        "free_period_days": (
                            listing.free_period_days
                        ),

                        # ----------------------------------
                        # DATES
                        # ----------------------------------

                        "active_from": listing.active_from,

                        "expires_at": listing.expires_at,

                        "created_at": listing.created_at,

                        "updated_at": listing.updated_at,

                        # ----------------------------------
                        # IMAGES
                        # ----------------------------------

                        "images": image_data
                    }
                },

                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            print("====================================")
            print("BAZAAR LISTING CREATE ERROR")
            print("ERROR:", str(e))
            print("====================================")

            return Response(
                {
                    "success": False,
                    "message": (
                        "Something went wrong while "
                        "creating listing."
                    ),
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class BazaarListingUpdateAPIView(APIView):

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):

        try:

            print("====================================")
            print("BAZAAR LISTING UPDATE")
            print("USER:", request.user)
            print("DATA:", request.data)
            print("FILES:", request.FILES)
            print("====================================")

            # ==========================================
            # LISTING ID FROM REQUEST
            # ==========================================

            listing_id = request.data.get(
                "listing_id"
            )

            if not listing_id:

                return Response(
                    {
                        "success": False,
                        "message": "listing_id is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==========================================
            # GET LISTING
            # ==========================================

            try:

                listing = BazaarListing.objects.select_related(
                    "category",
                    "subcategory",
                    "user"
                ).get(
                    id=listing_id,
                    user=request.user
                )

            except BazaarListing.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message":
                        "Listing not found or you do not have permission to update it."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # ==========================================
            # SERIALIZER
            # ==========================================

            serializer = BazaarListingUpdateSerializer(
                listing,
                data=request.data,
                partial=True
            )

            if not serializer.is_valid():

                return Response(
                    {
                        "success": False,
                        "message": "Listing update failed.",
                        "errors": serializer.errors
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==========================================
            # UPDATE LISTING
            # ==========================================

            listing = serializer.save()

            # ==========================================
            # DELETE IMAGES
            # ==========================================

            delete_image_ids = request.data.get(
                "delete_image_ids"
            )

            if delete_image_ids:

                if isinstance(
                    delete_image_ids,
                    str
                ):

                    try:

                        delete_image_ids = json.loads(
                            delete_image_ids
                        )

                    except json.JSONDecodeError:

                        delete_image_ids = [
                            x.strip()
                            for x in delete_image_ids.split(",")
                            if x.strip()
                        ]

                for image_id in delete_image_ids:

                    try:

                        listing_image = (
                            BazaarListingImage.objects.get(
                                id=image_id,
                                listing=listing
                            )
                        )

                        # Delete S3 image
                        try:

                            delete_bazaar_listing_image(
                                listing_image.image_s3_key
                            )

                        except Exception as image_error:

                            print(
                                "S3 DELETE ERROR:",
                                str(image_error)
                            )

                        # Delete DB record
                        listing_image.delete()

                    except BazaarListingImage.DoesNotExist:

                        continue

            # ==========================================
            # NEW IMAGES
            # ==========================================

            images = request.FILES.getlist(
                "images"
            )

            for image in images:

                print(
                    "Uploading new image:",
                    image.name
                )

                s3_key = upload_bazaar_listing_image(
                    image,
                    listing.id
                )

                # Current image count
                current_count = (
                    BazaarListingImage.objects.filter(
                        listing=listing
                    ).count()
                )

                # Max sort order
                max_sort_order = (
                    BazaarListingImage.objects.filter(
                        listing=listing
                    ).aggregate(
                        max_order=Max("sort_order")
                    )["max_order"]
                )

                if max_sort_order is None:
                    max_sort_order = -1

                # If no image exists, new image becomes primary
                is_primary = (
                    current_count == 0
                )

                BazaarListingImage.objects.create(
                    listing=listing,
                    image_s3_key=s3_key,
                    is_primary=is_primary,
                    sort_order=max_sort_order + 1
                )

            # ==========================================
            # IMAGE RESPONSE
            # ==========================================

            listing_images = (
                BazaarListingImage.objects.filter(
                    listing=listing
                ).order_by(
                    "sort_order",
                    "id"
                )
            )

            image_data = []

            for listing_image in listing_images:

                image_data.append(
                    {
                        "id": listing_image.id,

                        "image_s3_key":
                            listing_image.image_s3_key,

                        "image_url":
                            get_bazaar_image_url(
                                listing_image.image_s3_key
                            ),

                        "is_primary":
                            listing_image.is_primary,

                        "sort_order":
                            listing_image.sort_order
                    }
                )

            # ==========================================
            # SUCCESS
            # ==========================================

            return Response(
                {
                    "success": True,

                    "message":
                        "Listing updated successfully.",

                    "data": {

                        "id": listing.id,

                        "user_id": listing.user.id,

                        # CATEGORY
                        "category_id":
                            listing.category.id,

                        "category_name":
                            listing.category.name,

                        # SUBCATEGORY
                        "subcategory_id":
                            (
                                listing.subcategory.id
                                if listing.subcategory
                                else None
                            ),

                        "subcategory_name":
                            (
                                listing.subcategory.name
                                if listing.subcategory
                                else None
                            ),

                        # BASIC
                        "title":
                            listing.title,

                        "description":
                            listing.description,

                        "price":
                            float(listing.price),

                        "is_negotiable":
                            listing.is_negotiable,

                        "condition":
                            listing.condition,

                        "seller_type":
                            listing.seller_type,

                        # LOCATION
                        "city":
                            listing.city,

                        "area":
                            listing.area,

                        "address":
                            listing.address,

                        "pincode":
                            listing.pincode,

                        "latitude":
                            (
                                float(listing.latitude)
                                if listing.latitude is not None
                                else None
                            ),

                        "longitude":
                            (
                                float(listing.longitude)
                                if listing.longitude is not None
                                else None
                            ),

                        # ATTRIBUTES
                        "attributes":
                            listing.attributes,

                        # STATUS
                        "status":
                            listing.status,

                        # FEATURED
                        "is_featured":
                            listing.is_featured,

                        # FIRST LISTING
                        "is_first_listing":
                            listing.is_first_listing,

                        "free_period_days":
                            listing.free_period_days,

                        # DATES
                        "active_from":
                            listing.active_from,

                        "expires_at":
                            listing.expires_at,

                        "created_at":
                            listing.created_at,

                        "updated_at":
                            listing.updated_at,

                        # IMAGES
                        "images":
                            image_data
                    }
                },

                status=status.HTTP_200_OK
            )

        except Exception as e:

            print("====================================")
            print("BAZAAR LISTING UPDATE ERROR")
            print("ERROR:", str(e))
            print("====================================")

            return Response(
                {
                    "success": False,
                    "message":
                        "Something went wrong while updating listing.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )        
        
class BazaarListingListAPIView(APIView):

    def post(self, request):

        try:

            # ==========================================
            # BASE QUERY
            # ONLY ACTIVE LISTINGS
            # ==========================================

            listings = (
                BazaarListing.objects
                .select_related(
                    "user",
                    "category",
                    "subcategory",
                )
                .prefetch_related(
                    Prefetch(
                        "images",
                        queryset=BazaarListingImage.objects.order_by(
                            "sort_order",
                            "id"
                        )
                    )
                )
                .filter(
                    status="active"
                )
                .order_by("-created_at")
            )

            # ==========================================
            # FILTERS
            # ==========================================

            category_id = request.GET.get("category_id")
            subcategory_id = request.GET.get("subcategory_id")
            city = request.GET.get("city")
            seller_type = request.GET.get("seller_type")
            condition = request.GET.get("condition")
            search = request.GET.get("search")

            # ==========================================
            # CATEGORY FILTER
            # ==========================================

            if category_id:

                listings = listings.filter(
                    category_id=category_id
                )

            # ==========================================
            # SUBCATEGORY FILTER
            # ==========================================

            if subcategory_id:

                listings = listings.filter(
                    subcategory_id=subcategory_id
                )

            # ==========================================
            # CITY FILTER
            # ==========================================

            if city:

                listings = listings.filter(
                    city__iexact=city.strip()
                )

            # ==========================================
            # SELLER TYPE FILTER
            # ==========================================

            if seller_type:

                listings = listings.filter(
                    seller_type=seller_type
                )

            # ==========================================
            # CONDITION FILTER
            # ==========================================

            if condition:

                listings = listings.filter(
                    condition=condition
                )

            # ==========================================
            # SEARCH FILTER
            # ==========================================

            if search:

                search = search.strip()

                if search:

                    listings = listings.filter(
                        title__icontains=search
                    )

            # ==========================================
            # SERIALIZER
            # ==========================================

            serializer = BazaarListingListSerializer(
                listings,
                many=True
            )

            # ==========================================
            # RESPONSE
            # ==========================================

            return Response(
                {
                    "success": True,
                    "message": "Active listings fetched successfully.",
                    "count": listings.count(),
                    "data": serializer.data,
                },
                status=status.HTTP_200_OK
            )

        # ==========================================
        # ERROR
        # ==========================================

        except Exception as e:

            print(
                "BAZAAR LISTING LIST ERROR:",
                str(e)
            )

            return Response(
                {
                    "success": False,
                    "message": "Something went wrong while fetching listings.",
                    "error": str(e),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        
        
class BazaarListingDetailAPIView(APIView):

    permission_classes = []

    def post(self, request):

        try:
            listing_id = request.data.get("id")

            if not listing_id:
                return Response({
                    "success": False,
                    "message": "Listing id is required"
                }, status=400)

            listing = BazaarListing.objects.select_related(
                "category",
                "subcategory",
                "user"
            ).prefetch_related(
                "images"
            ).get(
                id=listing_id,
                status="active"
            )

        except BazaarListing.DoesNotExist:

            return Response({
                "success": False,
                "message": "Listing not found"
            }, status=404)

        listing.views_count += 1

        listing.save(
            update_fields=[
                "views_count",
                "updated_at"
            ]
        )

        return Response({
            "success": True,
            "data": BazaarListingSerializer(listing).data
        })
        
        
class MyBazaarListingAPIView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request):

        listings = BazaarListing.objects.filter(
            user=request.user
        ).prefetch_related(
            "images"
        )

        serializer = BazaarListingSerializer(
            listings,
            many=True
        )

        return Response({
            "success": True,
            "data": serializer.data
        })
        
class BazaarPlanCreateAPIView(APIView):

    def post(self, request):

        name = request.data.get("name")
        duration_days = request.data.get("duration_days")
        description = request.data.get("description", "")
        is_active = request.data.get("is_active", True)
        sort_order = request.data.get("sort_order", 0)

        # Required validation
        if not name:
            return Response(
                {
                    "success": False,
                    "message": "Plan name is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if duration_days is None:
            return Response(
                {
                    "success": False,
                    "message": "duration_days is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Duration validation
        try:
            duration_days = int(duration_days)

            if duration_days <= 0:
                return Response(
                    {
                        "success": False,
                        "message": "duration_days must be greater than 0."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

        except (ValueError, TypeError):

            return Response(
                {
                    "success": False,
                    "message": "duration_days must be a valid number."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Sort order validation
        try:
            sort_order = int(sort_order)

            if sort_order < 0:
                sort_order = 0

        except (ValueError, TypeError):
            sort_order = 0

        # Boolean validation
        if isinstance(is_active, str):
            is_active = is_active.lower() in [
                "true",
                "1",
                "yes"
            ]

        # Create plan
        plan = BazaarPlan.objects.create(
            name=name.strip(),
            duration_days=duration_days,
            description=description,
            is_active=is_active,
            sort_order=sort_order
        )

        serializer = BazaarPlanSerializer(plan)

        return Response(
            {
                "success": True,
                "message": "Bazaar plan created successfully.",
                "data": serializer.data
            },
            status=status.HTTP_201_CREATED
        )
        
class BazaarPlanListAPIView(APIView):

    permission_classes = []

    def post(self, request):

        plans = BazaarPlan.objects.filter(
            is_active=True
        )

        serializer = BazaarPlanSerializer(
            plans,
            many=True
        )

        return Response({
            "success": True,
            "data": serializer.data
        }) 
        
class BazaarPricingCreateAPIView(APIView):

    def post(self, request):

        try:

            category_id = request.data.get("category_id")
            plan_id = request.data.get("plan_id")
            price = request.data.get("price")
            is_active = request.data.get("is_active", True)

            # ==========================================
            # REQUIRED VALIDATION
            # ==========================================

            if not category_id:
                return Response(
                    {
                        "success": False,
                        "message": "category_id is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not plan_id:
                return Response(
                    {
                        "success": False,
                        "message": "plan_id is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if price is None:
                return Response(
                    {
                        "success": False,
                        "message": "price is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==========================================
            # CATEGORY
            # ==========================================

            try:

                category = BazaarCategory.objects.get(
                    id=category_id,
                    is_active=True
                )

            except BazaarCategory.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Category not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # ==========================================
            # PLAN
            # ==========================================

            try:

                plan = BazaarPlan.objects.get(
                    id=plan_id,
                    is_active=True
                )

            except BazaarPlan.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Plan not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # ==========================================
            # PRICE VALIDATION
            # ==========================================

            try:

                price = Decimal(str(price))

                if price < 0:

                    return Response(
                        {
                            "success": False,
                            "message": "Price cannot be negative."
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

            except (
                InvalidOperation,
                ValueError,
                TypeError
            ):

                return Response(
                    {
                        "success": False,
                        "message": "Price must be a valid amount."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==========================================
            # BOOLEAN
            # ==========================================

            if isinstance(is_active, str):

                is_active = is_active.lower() in [
                    "true",
                    "1",
                    "yes"
                ]

            # ==========================================
            # DUPLICATE CHECK
            # ==========================================

            if BazaarPricing.objects.filter(
                category=category,
                plan=plan
            ).exists():

                return Response(
                    {
                        "success": False,
                        "message":
                            "Pricing already exists for this category and plan."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==========================================
            # CREATE PRICING
            # ==========================================

            pricing = BazaarPricing.objects.create(
                category=category,
                plan=plan,
                price=price,
                is_active=is_active
            )

            # ==========================================
            # RESPONSE
            # ==========================================

            return Response(
                {
                    "success": True,
                    "message":
                        "Bazaar pricing created successfully.",
                    "data": {
                        "id": pricing.id,

                        "category_id":
                            pricing.category.id,

                        "category_name":
                            pricing.category.name,

                        "plan_id":
                            pricing.plan.id,

                        "plan_name":
                            pricing.plan.name,

                        "duration_days":
                            pricing.plan.duration_days,

                        "price":
                            str(pricing.price),

                        "is_active":
                            pricing.is_active
                       
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            print("====================================")
            print("BAZAAR PRICING CREATE ERROR")
            print("ERROR:", str(e))
            print("====================================")

            return Response(
                {
                    "success": False,
                    "message":
                        "Something went wrong while creating pricing.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )        
               
        
class BazaarPlanPricingListAPIView(APIView):


    def post(self, request):

        plan_id = request.data.get("plan_id")

        if not plan_id:
            return Response(
                {
                    "success": False,
                    "message": "plan_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            plan = BazaarPlan.objects.get(
                id=plan_id,
                is_active=True
            )
        except BazaarPlan.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Plan not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        pricing = BazaarPricing.objects.filter(
            plan=plan,
            is_active=True,
            category__is_active=True
        ).select_related(
            "category"
        ).order_by(
            "category__sort_order",
            "category__name"
        )

        data = []

        for item in pricing:

            data.append(
                {
                    "id": item.id,
                    "category_id": item.category.id,
                    "category_name": item.category.name,
                    "category_slug": item.category.slug,
                    "price": str(item.price),
                    "is_active": item.is_active
                }
            )

        return Response(
            {
                "success": True,
                "message": "Pricing fetched successfully.",
                "plan": {
                    "id": plan.id,
                    "name": plan.name,
                    "duration_days": plan.duration_days,
                    "description": plan.description
                },
                "count": len(data),
                "data": data
            },
            status=status.HTTP_200_OK
        )
        
class ExpireBazaarListingsAPIView(APIView):

    permission_classes = []

    def post(self, request):

        now = timezone.now()

        updated = BazaarListing.objects.filter(
            status="active",
            expires_at__lte=now
        ).update(
            status="expired"
        )

        return Response({
            "success": True,
            "expired_count": updated
        })                                        
        
        
        
import razorpay

from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from .models import (
    BazaarListing,
    BazaarPlan,
    BazaarPricing,
    BazaarPayment,
)


# ============================================================
# CREATE RAZORPAY PAYMENT
# ============================================================

class BazaarCreatePaymentAPIView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    @transaction.atomic
    def post(self, request):

        try:

            # --------------------------------
            # REQUEST DATA
            # --------------------------------

            listing_id = request.data.get(
                "listing_id"
            )

            plan_id = request.data.get(
                "plan_id"
            )

            if not listing_id or not plan_id:

                return Response(
                    {
                        "success": False,
                        "message":
                            "listing_id and plan_id are required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --------------------------------
            # GET LISTING
            # --------------------------------

            try:

                listing = BazaarListing.objects.select_for_update().get(
                    id=listing_id,
                    user=request.user
                )

            except BazaarListing.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Listing not found"
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # --------------------------------
            # GET PLAN
            # --------------------------------

            try:

                plan = BazaarPlan.objects.get(
                    id=plan_id,
                    is_active=True
                )

            except BazaarPlan.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Invalid plan"
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # --------------------------------
            # CATEGORY + PLAN PRICING
            # --------------------------------

            try:

                pricing = BazaarPricing.objects.get(
                    category=listing.category,
                    plan=plan,
                    is_active=True
                )

            except BazaarPricing.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message":
                            "Pricing not available for this category and plan."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --------------------------------
            # PRICE
            # --------------------------------

            amount = pricing.price

            amount_paise = int(
                amount * Decimal("100")
            )

            if amount_paise <= 0:

                return Response(
                    {
                        "success": False,
                        "message":
                            "Invalid pricing amount."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --------------------------------
            # RAZORPAY CLIENT
            # --------------------------------

            client = razorpay.Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET
                )
            )

            # --------------------------------
            # CREATE RAZORPAY ORDER
            # --------------------------------

            razorpay_order = client.order.create(
                {
                    "amount": amount_paise,
                    "currency": "INR",
                    "payment_capture": 1
                }
            )

            # --------------------------------
            # CREATE PAYMENT RECORD
            # --------------------------------

            payment = BazaarPayment.objects.create(
                user=request.user,
                listing=listing,
                plan=plan,
                razorpay_order_id=razorpay_order["id"],
                amount=amount,
                status="created"
            )

            # --------------------------------
            # RESPONSE
            # --------------------------------

            return Response(
                {
                    "success": True,
                    "message":
                        "Razorpay order created successfully.",

                    "payment_id":
                        payment.id,

                    "razorpay_order_id":
                        razorpay_order["id"],

                    "amount":
                        str(amount),

                    "amount_paise":
                        amount_paise,

                    "currency":
                        "INR",

                    "razorpay_key":
                        settings.RAZORPAY_KEY_ID,

                    "listing": {
                        "id":
                            listing.id,

                        "title":
                            listing.title,

                        "category_id":
                            listing.category.id,

                        "category_name":
                            listing.category.name
                    },

                    "plan": {
                        "id":
                            plan.id,

                        "name":
                            plan.name,

                        "duration_days":
                            plan.duration_days,

                        "price":
                            str(pricing.price)
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            print("====================================")
            print("BAZAAR CREATE PAYMENT ERROR")
            print("ERROR:", str(e))
            print("====================================")

            return Response(
                {
                    "success": False,
                    "message":
                        "Something went wrong while creating payment.",
                    "error":
                        str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# ============================================================
# VERIFY RAZORPAY PAYMENT
# ============================================================

class BazaarVerifyPaymentAPIView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    @transaction.atomic
    def post(self, request):

        try:

            # --------------------------------
            # REQUEST DATA
            # --------------------------------

            razorpay_order_id = request.data.get(
                "razorpay_order_id"
            )

            razorpay_payment_id = request.data.get(
                "razorpay_payment_id"
            )

            razorpay_signature = request.data.get(
                "razorpay_signature"
            )

            if not all(
                [
                    razorpay_order_id,
                    razorpay_payment_id,
                    razorpay_signature
                ]
            ):

                return Response(
                    {
                        "success": False,
                        "message":
                            "Razorpay payment details are required"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --------------------------------
            # GET PAYMENT
            # --------------------------------

            try:

                payment = (
                    BazaarPayment.objects
                    .select_for_update()
                    .select_related(
                        "listing",
                        "plan",
                        "user"
                    )
                    .get(
                        razorpay_order_id=razorpay_order_id,
                        user=request.user
                    )
                )

            except BazaarPayment.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message":
                            "Payment record not found"
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # --------------------------------
            # ALREADY PAID
            # --------------------------------

            if payment.status == "paid":

                listing = payment.listing

                return Response(
                    {
                        "success": True,
                        "message":
                            "Payment already verified",

                        "payment_id":
                            payment.id,

                        "listing_id":
                            listing.id,

                        "status":
                            listing.status,

                        "expires_at":
                            listing.expires_at
                    },
                    status=status.HTTP_200_OK
                )

            # --------------------------------
            # RAZORPAY CLIENT
            # --------------------------------

            client = razorpay.Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET
                )
            )

            # --------------------------------
            # VERIFY SIGNATURE
            # --------------------------------

            try:

                client.utility.verify_payment_signature(
                    {
                        "razorpay_order_id":
                            razorpay_order_id,

                        "razorpay_payment_id":
                            razorpay_payment_id,

                        "razorpay_signature":
                            razorpay_signature
                    }
                )

            except Exception as e:

                print(
                    "RAZORPAY SIGNATURE ERROR:",
                    str(e)
                )

                payment.status = "failed"

                payment.save(
                    update_fields=[
                        "status"
                    ]
                )

                return Response(
                    {
                        "success": False,
                        "message":
                            "Payment verification failed"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --------------------------------
            # PAYMENT SUCCESS
            # --------------------------------

            payment.status = "paid"

            payment.razorpay_payment_id = (
                razorpay_payment_id
            )

            payment.razorpay_signature = (
                razorpay_signature
            )

            payment.paid_at = timezone.now()

            payment.save()

            # --------------------------------
            # ACTIVATE / RENEW LISTING
            # --------------------------------

            listing = payment.listing

            from .services import activate_paid_listing

            activate_paid_listing(
                listing,
                payment
            )

            # --------------------------------
            # REFRESH LISTING
            # --------------------------------

            listing.refresh_from_db()

            # --------------------------------
            # RESPONSE
            # --------------------------------

            return Response(
                {
                    "success": True,
                    "message":
                        "Payment verified and listing activated",

                    "payment_id":
                        payment.id,

                    "razorpay_payment_id":
                        payment.razorpay_payment_id,

                    "listing_id":
                        listing.id,

                    "status":
                        listing.status,

                    "active_from":
                        listing.active_from,

                    "expires_at":
                        listing.expires_at,

                    "plan": {
                        "id":
                            payment.plan.id,

                        "name":
                            payment.plan.name,

                        "duration_days":
                            payment.plan.duration_days
                    },

                    "amount":
                        str(payment.amount)
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            print("====================================")
            print("BAZAAR VERIFY PAYMENT ERROR")
            print("ERROR:", str(e))
            print("====================================")

            return Response(
                {
                    "success": False,
                    "message":
                        "Something went wrong while verifying payment.",
                    "error":
                        str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
class BazaarSubCategoryCreateAPIView(APIView):


    def post(self, request):

        serializer = BazaarSubCategoryCreateSerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                {
                    "success": False,
                    "message": "Subcategory creation failed.",
                    "errors": serializer.errors
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        subcategory = serializer.save()

        return Response(
            {
                "success": True,
                "message": "Subcategory created successfully.",
                "data": {
                    "id": subcategory.id,
                    "category": subcategory.category.id,
                    "category_name": subcategory.category.name,
                    "name": subcategory.name,
                    "slug": subcategory.slug,
                    "is_active": subcategory.is_active,
                    "sort_order": subcategory.sort_order,
                    "created_at": subcategory.created_at
                }
            },
            status=status.HTTP_201_CREATED
        )        
        
        
class BazaarSubCategoryListAPIView(APIView):

    def post(self, request):

        category_id = request.data.get("category_id")

        if not category_id:
            return Response(
                {
                    "success": False,
                    "message": "category_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            category = BazaarCategory.objects.get(
                id=category_id,
                is_active=True
            )

        except BazaarCategory.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Category not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        subcategories = BazaarSubCategory.objects.filter(
            category=category,
            is_active=True
        ).order_by(
            "sort_order",
            "name"
        )

        serializer = BazaarSubCategoryListSerializer(
            subcategories,
            many=True
        )

        return Response(
            {
                "success": True,
                "message": "Subcategories fetched successfully.",
                "category": {
                    "id": category.id,
                    "name": category.name,
                    "slug": category.slug
                },
                "count": subcategories.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
        
        
class BazaarSubCategoryDeleteAPIView(APIView):

    def delete(self, request):

        category_id = request.data.get("category_id")
        subcategory_id = request.data.get("subcategory_id")

        if not category_id:
            return Response(
                {
                    "success": False,
                    "message": "category_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not subcategory_id:
            return Response(
                {
                    "success": False,
                    "message": "subcategory_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            subcategory = BazaarSubCategory.objects.get(
                id=subcategory_id,
                category_id=category_id
            )

        except BazaarSubCategory.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Subcategory not found for this category."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        subcategory_name = subcategory.name

        subcategory.delete()

        return Response(
            {
                "success": True,
                "message": "Subcategory deleted successfully.",
                "data": {
                    "subcategory_id": subcategory_id,
                    "name": subcategory_name,
                    "category_id": category_id
                }
            },
            status=status.HTTP_200_OK
        )      
        
        
class BazaarAttributeCreateAPIView(APIView):

    def post(self, request):

        serializer = BazaarAttributeCreateSerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                {
                    "success": False,
                    "message": "Attribute creation failed.",
                    "errors": serializer.errors
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        attribute = serializer.save()

        return Response(
            {
                "success": True,
                "message": "Attribute created successfully.",
                "data": {
                    "id": attribute.id,
                    "category_id": attribute.category.id,
                    "category_name": attribute.category.name,

                    "subcategory_id": (
                        attribute.subcategory.id
                        if attribute.subcategory
                        else None
                    ),

                    "subcategory_name": (
                        attribute.subcategory.name
                        if attribute.subcategory
                        else None
                    ),

                    "name": attribute.name,
                    "key": attribute.key,
                    "field_type": attribute.field_type,
                    "options": attribute.options,
                    "is_required": attribute.is_required,
                    "is_active": attribute.is_active,
                    "sort_order": attribute.sort_order
                }
            },
            status=status.HTTP_201_CREATED
        )     
        
        
        
class BazaarAttributeListAPIView(APIView):

    def post(self, request):

        category_id = request.data.get("category_id")
        subcategory_id = request.data.get("subcategory_id")

        if not category_id:
            return Response(
                {
                    "success": False,
                    "message": "category_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not subcategory_id:
            return Response(
                {
                    "success": False,
                    "message": "subcategory_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Category check
        try:

            category = BazaarCategory.objects.get(
                id=category_id,
                is_active=True
            )

        except BazaarCategory.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Category not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # Subcategory check
        try:

            subcategory = BazaarSubCategory.objects.get(
                id=subcategory_id,
                category=category,
                is_active=True
            )

        except BazaarSubCategory.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Subcategory not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # Fetch attributes
        attributes = BazaarAttribute.objects.filter(
            category=category,
            subcategory=subcategory,
            is_active=True
        ).order_by(
            "sort_order",
            "id"
        )

        serializer = BazaarAttributeSerializer(
            attributes,
            many=True
        )

        return Response(
            {
                "success": True,
                "message": "Attributes fetched successfully.",
                "category": {
                    "id": category.id,
                    "name": category.name,
                    "slug": category.slug
                },
                "subcategory": {
                    "id": subcategory.id,
                    "name": subcategory.name,
                    "slug": subcategory.slug
                },
                "count": attributes.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )             

      
class BazaarEnquiryCreateAPIView(APIView):

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):

        # ==================================================
        # 1. REQUEST DATA
        # ==================================================

        listing_id = request.data.get("listing_id")
        message = request.data.get("message")
        phone_number = request.data.get("phone_number")

        # ==================================================
        # 2. VALIDATION
        # ==================================================

        if not listing_id:
            return Response(
                {
                    "success": False,
                    "message": "listing_id is required",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not message or not str(message).strip():
            return Response(
                {
                    "success": False,
                    "message": "message is required",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        message = str(message).strip()

        # ==================================================
        # Mobile Number Validation
        # ==================================================

        if phone_number:

            phone_number = str(phone_number).strip()

            # Indian mobile number:
            # Exactly 10 digits
            # Must start with 6, 7, 8 or 9
            if not re.fullmatch(r"[6-9]\d{9}", phone_number):

                return Response(
                    {
                        "success": False,
                        "message": "Please enter a valid 10-digit mobile number."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )  

        # ==================================================
        # 3. GET ACTIVE LISTING
        # ==================================================

        try:
            listing = (
                BazaarListing.objects
                .select_related("user")
                .get(
                    id=listing_id,
                    status="active",
                )
            )

        except BazaarListing.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Listing not found",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # ==================================================
        # 4. PREVENT ENQUIRY ON OWN LISTING
        # ==================================================

        if listing.user_id == request.user.id:
            return Response(
                {
                    "success": False,
                    "message": (
                        "You cannot send enquiry on your own listing"
                    ),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ==================================================
        # 5. CHECK AND CONSUME ENQUIRY ALLOWANCE
        # ==================================================

        access_result = (
            BazaarCommunicationAccessService.consume(
                user=request.user,
                feature="enquiry",
            )
        )

        if not access_result.get("allowed", False):
            return Response(
                {
                    "success": False,
                    "message": access_result.get(
                        "message",
                        "Your enquiry limit has been reached. "
                        "Please purchase a communication plan "
                        "to continue.",
                    ),
                    "usage": access_result,
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        # ==================================================
        # 6. CREATE ENQUIRY
        # ==================================================

        enquiry = BazaarEnquiry.objects.create(
            listing=listing,
            user=request.user,
            message=message,
            phone_number=phone_number,
        )

        # ==================================================
        # 7. LISTING OWNER DETAILS
        # ==================================================

        owner = listing.user

        owner_name = (
            owner.name
            if owner.name
            else owner.username
        )

        owner_phone = owner.phone_number

        # ==================================================
        # 8. ENQUIRY USER DETAILS
        # ==================================================

        enquiry_user_name = (
            request.user.name
            if request.user.name
            else request.user.username
        )

        enquiry_user_phone = (
            phone_number
            if phone_number
            else request.user.phone_number
        )

        # ==================================================
        # 9. SEND WHATSAPP NOTIFICATION
        # ==================================================

        whatsapp_result = {
            "success": False,
            "status_code": None,
            "response": None,
            "error": "Owner phone number not available",
        }

        if owner_phone:
            whatsapp_result = send_bazaar_enquiry_message(
                owner_phone=owner_phone,
                owner_name=owner_name,
                listing_title=listing.title,
                listing_price=listing.price,
                enquiry_user_name=enquiry_user_name,
                enquiry_user_phone=enquiry_user_phone,
                enquiry_message=enquiry.message,
            )

        # ==================================================
        # 10. SUCCESS RESPONSE
        # ==================================================

        return Response(
            {
                "success": True,
                "message": "Enquiry submitted successfully",
                "data": {
                    "enquiry": {
                        "id": enquiry.id,
                        "status": enquiry.status,
                        "message": enquiry.message,
                        "phone_number": enquiry.phone_number,
                        "created_at": enquiry.created_at,
                    },
                    "listing": {
                        "id": listing.id,
                        "title": listing.title,
                        "price": str(listing.price),
                    },
                    "owner": {
                        "id": owner.id,
                        "name": owner_name,
                    },
                    "usage": access_result,
                    "whatsapp": {
                        "sent": whatsapp_result.get("success"),
                        "status_code": whatsapp_result.get(
                            "status_code"
                        ),
                        "response": whatsapp_result.get(
                            "response"
                        ),
                        "error": whatsapp_result.get(
                            "error"
                        ),
                    },
                },
            },
            status=status.HTTP_201_CREATED,
        )

                    
        
class BazaarEnquiryListAPIView(APIView):

    def post(self, request):

        enquiries = BazaarEnquiry.objects.filter(
            user=request.user
        ).select_related(
            "listing"
        ).order_by("-created_at")

        data = []

        for enquiry in enquiries:

            data.append({
                "id": enquiry.id,
                "listing_id": enquiry.listing.id,
                "listing_title": enquiry.listing.title,
                "message": enquiry.message,
                "phone_number": enquiry.phone_number,
                "status": enquiry.status,
                "created_at": enquiry.created_at,
            })

        return Response({
            "success": True,
            "message": "Enquiries fetched successfully",
            "count": len(data),
            "data": data
        }, status=status.HTTP_200_OK)        
        
        
        
class BazaarSettingsCreateAPIView(APIView):

    def post(self, request):

        try:
            settings = BazaarSettings.objects.create(
                first_listing_free=request.data.get(
                    "first_listing_free", True
                ),
                free_listing_days=request.data.get(
                    "free_listing_days", 15
                ),
                payment_required_after_expiry=request.data.get(
                    "payment_required_after_expiry", True
                ),
                is_active=request.data.get(
                    "is_active", True
                )
            )

            return Response(
                {
                    "success": True,
                    "message": "Bazaar settings created successfully.",
                    "data": {
                        "id": settings.id,
                        "first_listing_free": settings.first_listing_free,
                        "free_listing_days": settings.free_listing_days,
                        "payment_required_after_expiry": settings.payment_required_after_expiry,
                        "is_active": settings.is_active,
                        "updated_at": settings.updated_at
                    }
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to create Bazaar settings.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
            
class BazaarSettingsListAPIView(APIView):

    def get(self, request):

        try:
            settings = BazaarSettings.objects.all().order_by("-id")

            data = []

            for item in settings:
                data.append({
                    "id": item.id,
                    "first_listing_free": item.first_listing_free,
                    "free_listing_days": item.free_listing_days,
                    "payment_required_after_expiry": item.payment_required_after_expiry,
                    "is_active": item.is_active,
                    "updated_at": item.updated_at
                })

            return Response(
                {
                    "success": True,
                    "message": "Bazaar settings fetched successfully.",
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to fetch Bazaar settings.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )            
            
            
class BazaarSettingsUpdateAPIView(APIView):

    def put(self, request):

        try:

            settings_id = request.data.get("id")

            if not settings_id:
                return Response(
                    {
                        "success": False,
                        "message": "id is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                settings = BazaarSettings.objects.get(
                    id=settings_id
                )
            except BazaarSettings.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Bazaar settings not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            if "first_listing_free" in request.data:
                settings.first_listing_free = request.data.get(
                    "first_listing_free"
                )

            if "free_listing_days" in request.data:
                settings.free_listing_days = request.data.get(
                    "free_listing_days"
                )

            if "payment_required_after_expiry" in request.data:
                settings.payment_required_after_expiry = request.data.get(
                    "payment_required_after_expiry"
                )

            if "is_active" in request.data:
                settings.is_active = request.data.get(
                    "is_active"
                )

            settings.save()

            return Response(
                {
                    "success": True,
                    "message": "Bazaar settings updated successfully.",
                    "data": {
                        "id": settings.id,
                        "first_listing_free": settings.first_listing_free,
                        "free_listing_days": settings.free_listing_days,
                        "payment_required_after_expiry": settings.payment_required_after_expiry,
                        "is_active": settings.is_active,
                        "updated_at": settings.updated_at
                    }
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to update Bazaar settings.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )                       

    


















##############################################################################
##############################################################################
#            OLX ENQUIRY AND QNX CHAT SUBCRIPTION PLAN VIEWS
##############################################################################
##############################################################################

# ============================================================
# BAZAAR COMMUNICATION SUBSCRIPTION APIs
# Append this section to the existing olx/views.py.
# Do not delete your existing views.
# ============================================================

# ============================================================
# SHARED SETTINGS HELPER
# ============================================================

def get_communication_settings():
    """
    Return the first active global settings record.
    Create defaults if none exist.
    """
    settings_obj = (
        BazaarCommunicationSettings.objects
        .filter(is_active=True)
        .order_by("-updated_at", "-id")
        .first()
    )
    if settings_obj is None:
        settings_obj = BazaarCommunicationSettings.objects.create(
            is_active=True
        )
    return settings_obj

# ============================================================
# 1. CREATE COMMUNICATION PLAN
# POST /api/olx/bazaar-communication-plans/create/
# ============================================================

class BazaarCommunicationPlanCreateAPIView(APIView):
    # permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = BazaarCommunicationPlanSerializer(
            data=request.data
        )
        if not serializer.is_valid():
            return Response(
                {
                    "success": False,
                    "message": "Communication plan validation failed.",
                    "errors": serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        plan = serializer.save()
        return Response(
            {
                "success": True,
                "message": "Communication plan created successfully.",
                "data": BazaarCommunicationPlanSerializer(plan).data,
            },
            status=status.HTTP_201_CREATED,
        )

# ============================================================
# 2. LIST COMMUNICATION PLANS
# POST /api/olx/bazaar-communication-plans/list/
# ============================================================

class BazaarCommunicationPlanListAPIView(APIView):
    # permission_classes = [IsAuthenticated]

    def post(self, request):
        # Pass {"include_inactive": true} to retrieve inactive plans.
        include_inactive = (
            str(request.data.get("include_inactive", "false")).lower()
            in {"true", "1", "yes"}
        )
        plans = BazaarCommunicationPlan.objects.all()
        if not include_inactive:
            plans = plans.filter(is_active=True)
        plans = plans.order_by("price", "name")
        serializer = BazaarCommunicationPlanSerializer(
            plans,
            many=True,
        )
        return Response(
            {
                "success": True,
                "count": plans.count(),
                "data": serializer.data,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 3. UPDATE COMMUNICATION PLAN
# POST /api/olx/bazaar-communication-plans/update/
#
# Request example:
# {
#     "plan_id": 1,
#     "price": "199.00",
#     "duration_days": 30
# }
# ============================================================

class BazaarCommunicationPlanUpdateAPIView(APIView):
    # permission_classes = [IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get("plan_id")
        if not plan_id:
            return Response(
                {
                    "success": False,
                    "message": "plan_id is required.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        plan = get_object_or_404(
            BazaarCommunicationPlan,
            pk=plan_id,
        )
        # Do not pass plan_id into the model serializer.
        update_data = request.data.copy()
        update_data.pop("plan_id", None)
        serializer = BazaarCommunicationPlanSerializer(
            plan,
            data=update_data,
            partial=True,
        )
        if not serializer.is_valid():
            return Response(
                {
                    "success": False,
                    "message": "Communication plan update failed.",
                    "errors": serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        plan = serializer.save()
        return Response(
            {
                "success": True,
                "message": "Communication plan updated successfully.",
                "data": BazaarCommunicationPlanSerializer(plan).data,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 4. SOFT-DEACTIVATE COMMUNICATION PLAN
# POST /api/olx/bazaar-communication-plans/delete/
#
# Request:
# {"plan_id": 1}
# ============================================================

class BazaarCommunicationPlanDeleteAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get("plan_id")
        if not plan_id:
            return Response(
                {
                    "success": False,
                    "message": "plan_id is required.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        plan = get_object_or_404(
            BazaarCommunicationPlan,
            pk=plan_id,
        )
        if not plan.is_active:
            return Response(
                {
                    "success": True,
                    "message": "Communication plan is already inactive.",
                },
                status=status.HTTP_200_OK,
            )
        plan.is_active = False
        plan.save(update_fields=["is_active", "updated_at"])
        return Response(
            {
                "success": True,
                "message": "Communication plan deactivated successfully.",
                "plan_id": plan.id,
                "is_active": plan.is_active,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 5. GET GLOBAL COMMUNICATION SETTINGS
# POST /api/olx/bazaar-communication-settings/detail/
# ============================================================

class BazaarCommunicationSettingsDetailAPIView(APIView):
    # permission_classes = [IsAuthenticated]

    def post(self, request):
        settings_obj = get_communication_settings()
        serializer = BazaarCommunicationSettingsSerializer(
            settings_obj
        )
        return Response(
            {
                "success": True,
                "data": serializer.data,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 6. UPDATE GLOBAL COMMUNICATION SETTINGS
# POST /api/olx/bazaar-communication-settings/update/
# ============================================================

class BazaarCommunicationSettingsUpdateAPIView(APIView):
    # permission_classes = [IsAuthenticated]

    def post(self, request):
        settings_obj = get_communication_settings()
        serializer = BazaarCommunicationSettingsSerializer(
            settings_obj,
            data=request.data,
            partial=True,
        )
        if not serializer.is_valid():
            return Response(
                {
                    "success": False,
                    "message": "Settings validation failed.",
                    "errors": serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        settings_obj = serializer.save()
        return Response(
            {
                "success": True,
                "message": "Communication settings updated successfully.",
                "data": BazaarCommunicationSettingsSerializer(
                    settings_obj
                ).data,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 7. LIST MY COMMUNICATION SUBSCRIPTIONS
# POST /api/olx/bazaar-communication-subscriptions/my/
# ============================================================

class BazaarCommunicationMySubscriptionsAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        paid_subscription_ids = (
            BazaarCommunicationPayment.objects
            .filter(
                user=request.user,
                status="paid",
                subscription__isnull=False,
            )
            .values_list("subscription_id", flat=True)
        )

        subscriptions = (
            BazaarCommunicationSubscription.objects
            .filter(
                user=request.user,
                is_active=True,
                id__in=paid_subscription_ids,
            )
            .select_related("plan")
            .order_by("-created_at")
        )
        serializer = BazaarCommunicationSubscriptionSerializer(
            subscriptions,
            many=True,
        )
        return Response(
            {
                "success": True,
                "count": subscriptions.count(),
                "data": serializer.data,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 8. MY SUBSCRIPTION DETAIL
# POST /api/olx/bazaar-communication-subscriptions/detail/
#
# Request:
# {"subscription_id": 1}
# ============================================================

class BazaarCommunicationSubscriptionDetailAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        subscription_id = request.data.get("subscription_id")
        if not subscription_id:
            return Response(
                {
                    "success": False,
                    "message": "subscription_id is required.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        subscription = get_object_or_404(
            BazaarCommunicationSubscription.objects.select_related(
                "plan"
            ),
            pk=subscription_id,
            user=request.user,
            is_active=True,
        )
        serializer = BazaarCommunicationSubscriptionSerializer(
            subscription
        )
        return Response(
            {
                "success": True,
                "data": serializer.data,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 9. CHAT USAGE STATUS
# POST /api/olx/bazaar-communication-usage/chat/
# ============================================================

class BazaarCommunicationChatUsageAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        result = BazaarCommunicationAccessService.get_status(
            user=request.user,
            feature="chat",
        )
        return Response(
            {
                "success": True,
                "data": result,
            },
            status=status.HTTP_200_OK,
        )

# ============================================================
# 10. ENQUIRY USAGE STATUS
# POST /api/olx/bazaar-communication-usage/enquiry/
# ============================================================

class BazaarCommunicationEnquiryUsageAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        result = BazaarCommunicationAccessService.get_status(
            user=request.user,
            feature="enquiry",
        )
        return Response(
            {
                "success": True,
                "data": result,
            },
            status=status.HTTP_200_OK,
        )






##############################################################################
##############################################################################
#                               QNX CHAT VIEWS
##############################################################################
##############################################################################

# ---------------------------------------------------------
# Contact information validation
# ---------------------------------------------------------

EMAIL_PATTERN = re.compile(
    r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b",
    re.IGNORECASE,
)
PHONE_PATTERN = re.compile(
    r"(?<!\w)(?:\+?\d[\d\s().-]{7,}\d)(?!\w)"
)
URL_PATTERN = re.compile(
    r"(?:https?://|www\.)\S+|"
    r"\b[a-zA-Z0-9-]+\.(?:com|in|net|org|io|co|me|app|dev|info|xyz)"
    r"(?:/\S*)?",
    re.IGNORECASE,
)
SOCIAL_PATTERN = re.compile(
    r"@\w{2,}|"
    r"\b(?:instagram|insta|telegram|whatsapp|facebook|snapchat|"
    r"twitter|tiktok|discord)\b"
    r".{0,30}\b(?:id|handle|username|me|dm|message|contact|follow)\b|"
    r"\b(?:dm|message|contact|follow)\b"
    r".{0,30}\b(?:instagram|insta|telegram|whatsapp|facebook|snapchat|"
    r"twitter|tiktok|discord)\b",
    re.IGNORECASE,
)

def get_bazaar_communication_settings():
    return BazaarCommunicationSettings.objects.filter(
        is_active=True
    ).first()

def detect_contact_information(message, settings_obj):
    """
    Returns an error message when a configured contact restriction
    is triggered. Returns None when no configured rule is triggered.
    """
    if not settings_obj:
        return None

    email_found = bool(EMAIL_PATTERN.search(message))
    phone_found = bool(PHONE_PATTERN.search(message))
    url_found = bool(URL_PATTERN.search(message))
    social_found = bool(SOCIAL_PATTERN.search(message))

    # The umbrella setting blocks any detected contact information.
    if settings_obj.block_contact_info:
        if email_found or phone_found or url_found or social_found:
            return "Messages containing contact information are not allowed."

    if settings_obj.block_phone_numbers and phone_found:
        return "Phone numbers are not allowed in messages."

    if settings_obj.block_emails and email_found:
        return "Email addresses are not allowed in messages."

    if settings_obj.block_external_links and url_found:
        return "External links are not allowed in messages."

    if settings_obj.block_social_handles and social_found:
        return "Social media contact details are not allowed in messages."

    return None

# ---------------------------------------------------------
# Pagination
# ---------------------------------------------------------

class BazaarChatMessagePagination(PageNumberPagination):
    page_size = 30
    page_size_query_param = "page_size"
    max_page_size = 100

# ---------------------------------------------------------
# Create or retrieve a conversation
# POST /chats/create/
# ---------------------------------------------------------


class BazaarChatCreateAPIView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = BazaarChatCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        other_user_id = serializer.validated_data["other_user_id"]
        current_user = request.user

        # Prevent chatting with yourself.
        if current_user.pk == other_user_id:
            return Response(
                {"detail": "You cannot create a chat with yourself."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validate the other participant.
        other_user = User.objects.filter(pk=other_user_id).first()

        if not other_user:
            return Response(
                {"detail": "The requested user does not exist."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Lock both users in a consistent order to reduce
        # duplicate creation during concurrent requests.
        locked_users = list(
            User.objects.select_for_update()
            .filter(pk__in=[current_user.pk, other_user.pk])
            .order_by("pk")
        )

        users_by_id = {user.pk: user for user in locked_users}

        current_user = users_by_id[current_user.pk]
        other_user = users_by_id[other_user.pk]

        # Always store the pair in canonical numeric order.
        user_one, user_two = sorted(
            [current_user, other_user],
            key=lambda user: user.pk,
        )

        # One conversation per user pair.
        # Listing does not participate in chat identity.
        chat = (
            BazaarChat.objects.filter(
                user_one=user_one,
                user_two=user_two,
                is_active=True,
            )
            .first()
        )

        created = False

        if chat is None:
            chat = BazaarChat.objects.create(
                user_one=user_one,
                user_two=user_two,
                listing=None,
            )
            created = True

        response_serializer = BazaarChatSerializer(
            chat,
            context={"request": request},
        )

        return Response(
            {
                "created": created,
                "chat": response_serializer.data,
            },
            status=(
                status.HTTP_201_CREATED
                if created
                else status.HTTP_200_OK
            ),
        )


# ---------------------------------------------------------
# List current user's conversations
# GET /chats/
# ---------------------------------------------------------

class BazaarChatListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        chats = (
            BazaarChat.objects
            .filter(
                Q(user_one=request.user) |
                Q(user_two=request.user),
                is_active=True,
            )
            .select_related("user_one", "user_two", "listing")
            .order_by("-updated_at")
        )
        serializer = BazaarChatSerializer(
            chats,
            many=True,
            context={"request": request},
        )
        return Response(
            {"results": serializer.data},
            status=status.HTTP_200_OK,
        )

# ---------------------------------------------------------
# Shared participant authorization
# ---------------------------------------------------------

class BazaarChatParticipantAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_chat(self, request, chat_id):
        return BazaarChat.objects.filter(
            pk=chat_id,
            is_active=True,
        ).filter(
            Q(user_one=request.user) |
            Q(user_two=request.user)
        ).first()

# ---------------------------------------------------------
# Retrieve messages in a conversation
# GET /chats/<chat_id>/messages/
# ---------------------------------------------------------

class BazaarChatMessageListAPIView(BazaarChatParticipantAPIView):
    pagination_class = BazaarChatMessagePagination

    def get(self, request, chat_id):
        chat = self.get_chat(request, chat_id)

        if not chat:
            return Response(
                {"detail": "Chat not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        messages = (
            BazaarChatMessage.objects
            .filter(
                chat=chat,
                is_active=True,
                moderation_status=BazaarChatMessage.ModerationStatus.ALLOWED,
            )
            .select_related("sender")
            .order_by("created_at", "id")
        )
        paginator = self.pagination_class()
        page = paginator.paginate_queryset(
            messages,
            request,
            view=self,
        )
        serializer = BazaarChatMessageSerializer(
            page,
            many=True,
        )
        return paginator.get_paginated_response(serializer.data)

# ---------------------------------------------------------
# Send a message
# POST /chats/<chat_id>/messages/send/
# ---------------------------------------------------------

class BazaarChatMessageSendAPIView(BazaarChatParticipantAPIView):

    @transaction.atomic
    def post(self, request, chat_id):
        chat = (
            BazaarChat.objects
            .select_for_update()
            .filter(
                pk=chat_id,
                is_active=True,
            )
            .filter(
                Q(user_one=request.user) |
                Q(user_two=request.user)
            )
            .first()
        )

        if not chat:
            return Response(
                {"detail": "Chat not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = BazaarChatMessageCreateSerializer(
            data=request.data,
        )
        serializer.is_valid(raise_exception=True)
        message_text = serializer.validated_data["message"]

        # Check contact restrictions before consuming allowance.
        settings_obj = get_bazaar_communication_settings()
        contact_error = detect_contact_information(
            message_text,
            settings_obj,
        )
        if contact_error:
            return Response(
                {
                    "detail": contact_error,
                    "code": "contact_information_not_allowed",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Consume one outgoing-message allowance.
        access_result = BazaarCommunicationAccessService.consume(
            user=request.user,
            feature="chat",
        )
        if not access_result.get("allowed", False):
            return Response(
                {
                    "detail": access_result.get(
                        "message",
                        "Your messaging allowance has been exhausted.",
                    ),
                    "code": "chat_limit_reached",
                    "access": access_result,
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        message = BazaarChatMessage.objects.create(
            chat=chat,
            sender=request.user,
            message=message_text,
            moderation_status=(
                BazaarChatMessage.ModerationStatus.ALLOWED
            ),
        )
        chat.updated_at = timezone.now()
        chat.save(update_fields=["updated_at"])

        return Response(
            {
                "detail": "Message sent successfully.",
                "message": BazaarChatMessageSerializer(message).data,
                "access": access_result,
            },
            status=status.HTTP_201_CREATED,
        )

# ---------------------------------------------------------
# Mark incoming messages as read
# POST /chats/<chat_id>/read/
# ---------------------------------------------------------

class BazaarChatMarkReadAPIView(BazaarChatParticipantAPIView):

    @transaction.atomic
    def post(self, request, chat_id):
        chat = self.get_chat(request, chat_id)

        if not chat:
            return Response(
                {"detail": "Chat not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        updated_count = (
            BazaarChatMessage.objects
            .filter(
                chat=chat,
                is_active=True,
                is_read=False,
            )
            .exclude(sender=request.user)
            .update(
                is_read=True,
                read_at=timezone.now(),
            )
        )

        return Response(
            {
                "detail": "Messages marked as read.",
                "updated_count": updated_count,
            },
            status=status.HTTP_200_OK,
        )