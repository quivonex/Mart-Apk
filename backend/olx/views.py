from django.db import transaction
from django.utils import timezone
from django.db.models import Prefetch
from rest_framework.views import APIView
from rest_framework.response import Response
from decimal import Decimal, InvalidOperation
from rest_framework import status
import json

from .models import BazaarEnquiry
from .whatsapp import send_bazaar_enquiry_message
from django.db.models import Max
from django.db import transaction
from rest_framework.permissions import IsAuthenticated
from .s3_upload import upload_bazaar_listing_image,get_bazaar_image_url, delete_bazaar_listing_image

from .models import (
    BazaarCategory,
    BazaarSubCategory,
    BazaarAttribute,
    BazaarListing,
    BazaarListingImage,
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
    BazaarListingUpdateSerializer
)

from .services import (
    get_bazaar_settings,
    get_user_listing_count,
    activate_first_listing,
)

from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from .models import BazaarCategory
from .serializers import BazaarCategoryCreateSerializer


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

            # ==========================================
            # SERIALIZER
            # ==========================================

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

            # ==========================================
            # CREATE LISTING
            # ==========================================

            listing = serializer.save(
                user=request.user
            )

            # ==========================================
            # GET MULTIPLE IMAGES
            # ==========================================

            images = request.FILES.getlist("images")

            image_data = []

            # ==========================================
            # S3 IMAGE UPLOAD
            # ==========================================

            for index, image in enumerate(images):

                print(
                    f"Uploading image {index + 1}:",
                    image.name
                )

                # Upload image to S3
                s3_key = upload_bazaar_listing_image(
                    image,
                    listing.id
                )

                # Save image record
                listing_image = BazaarListingImage.objects.create(
                    listing=listing,
                    image_s3_key=s3_key,
                    is_primary=(index == 0),
                    sort_order=index
                )

                # ======================================
                # IMAGE RESPONSE
                # ======================================

                image_data.append(
                    {
                        "id": listing_image.id,

                        "image_s3_key": listing_image.image_s3_key,

                        "image_url": get_bazaar_image_url(
                            listing_image.image_s3_key
                        ),

                        "is_primary": listing_image.is_primary,

                        "sort_order": listing_image.sort_order
                    }
                )

            # ==========================================
            # SUCCESS RESPONSE
            # ==========================================

            return Response(
                {
                    "success": True,

                    "message": "Listing created successfully.",

                    "data": {

                        "id": listing.id,

                        "user_id": listing.user.id,

                        # ------------------------------
                        # CATEGORY
                        # ------------------------------

                        "category_id": listing.category.id,

                        "category_name": listing.category.name,

                        # ------------------------------
                        # SUBCATEGORY
                        # ------------------------------

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

                        # ------------------------------
                        # BASIC DETAILS
                        # ------------------------------

                        "title": listing.title,

                        "description": listing.description,

                        "price": float(listing.price),

                        "is_negotiable": listing.is_negotiable,

                        "condition": listing.condition,

                        "seller_type": listing.seller_type,

                        # ------------------------------
                        # LOCATION
                        # ------------------------------

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

                        # ------------------------------
                        # ATTRIBUTES
                        # ------------------------------

                        "attributes": listing.attributes,

                        # ------------------------------
                        # STATUS
                        # ------------------------------

                        "status": listing.status,

                        # ------------------------------
                        # FEATURED
                        # ------------------------------

                        "is_featured": listing.is_featured,

                        # ------------------------------
                        # FIRST LISTING
                        # ------------------------------

                        "is_first_listing": listing.is_first_listing,

                        "free_period_days": listing.free_period_days,

                        # ------------------------------
                        # DATES
                        # ------------------------------

                        "active_from": listing.active_from,

                        "expires_at": listing.expires_at,

                        "created_at": listing.created_at,

                        "updated_at": listing.updated_at,

                        # ------------------------------
                        # IMAGES
                        # ------------------------------

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
                    "message": "Something went wrong while creating listing.",
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

    def post(self, request):

        # ==================================================
        # 1. Request Data
        # ==================================================

        listing_id = request.data.get("listing_id")
        message = request.data.get("message")
        phone_number = request.data.get("phone_number")

        # ==================================================
        # 2. Validation
        # ==================================================

        if not listing_id:
            return Response(
                {
                    "success": False,
                    "message": "listing_id is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not message or not str(message).strip():
            return Response(
                {
                    "success": False,
                    "message": "message is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==================================================
        # 3. Get Active Listing
        # ==================================================

        try:

            listing = (
                BazaarListing.objects
                .select_related("user")
                .get(
                    id=listing_id,
                    status="active"
                )
            )

        except BazaarListing.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Listing not found"
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # ==================================================
        # 4. Prevent Own Listing Enquiry
        # ==================================================

        if listing.user_id == request.user.id:

            return Response(
                {
                    "success": False,
                    "message": "You cannot send enquiry on your own listing"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==================================================
        # 5. Create Enquiry
        # ==================================================

        enquiry = BazaarEnquiry.objects.create(
            listing=listing,
            user=request.user,
            message=str(message).strip(),
            phone_number=phone_number
        )

        # ==================================================
        # 6. Listing Owner
        # ==================================================

        owner = listing.user

        owner_name = (
            owner.name
            if owner.name
            else owner.username
        )

        owner_phone = owner.phone_number

        # ==================================================
        # 7. Enquiry User Details
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
        # 8. Send WhatsApp to Listing Owner
        # ==================================================

        whatsapp_result = {
            "success": False,
            "status_code": None,
            "response": None,
            "error": "Owner phone number not available"
        }

        if owner_phone:

            whatsapp_result = send_bazaar_enquiry_message(

                owner_phone=owner_phone,

                owner_name=owner_name,

                listing_title=listing.title,

                listing_price=listing.price,

                enquiry_user_name=enquiry_user_name,

                enquiry_user_phone=enquiry_user_phone,

                enquiry_message=enquiry.message
            )

        # ==================================================
        # 9. Response
        # ==================================================

        return Response(
            {
                "success": True,

                "message": "Enquiry submitted successfully",

                "data": {

                    # --------------------------------------
                    # Enquiry
                    # --------------------------------------

                    "enquiry": {
                        "id": enquiry.id,
                        "status": enquiry.status,
                        "message": enquiry.message,
                        "phone_number": enquiry.phone_number,
                        "created_at": enquiry.created_at,
                    },

                    # --------------------------------------
                    # Listing
                    # --------------------------------------

                    "listing": {
                        "id": listing.id,
                        "title": listing.title,
                        "price": str(listing.price),
                    },

                    # --------------------------------------
                    # Owner
                    # --------------------------------------

                    "owner": {
                        "id": owner.id,
                        "name": owner_name,
                    },

                    # --------------------------------------
                    # WhatsApp
                    # --------------------------------------

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
                    }
                }
            },
            status=status.HTTP_201_CREATED
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