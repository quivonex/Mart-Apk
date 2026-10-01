from rest_framework import serializers

from real_estate.utils import check_property_subscription
from .models import (Property,PropertyImage,PropertyVideo,PropertyDocument,Amenity,PropertyEnquiry)
from .models import Builder
import json


class AmenityCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Amenity
        fields = "__all__"

    def validate_name(self, value):
        if Amenity.objects.filter(name__iexact=value).exists():
            raise serializers.ValidationError("Amenity name already exists.")
        return value

    def validate_slug(self, value):
        if Amenity.objects.filter(slug=value).exists():
            raise serializers.ValidationError("Slug already exists.")
        return value


from rest_framework import serializers
from .models import Builder


class BuilderSerializer(serializers.ModelSerializer):

    class Meta:
        model = Builder
        fields = "__all__"
        read_only_fields = [
            "id",
            "created_at",
            "updated_at"
        ]

    def validate_website(self, value):

        if not value:
            return value

        value = value.strip()

        # www.example.com असेल तर https:// add करा
        if value.startswith("www."):
            value = "https://" + value

        # example.com पण accept करायचे असल्यास
        elif not value.startswith(("http://", "https://")):
            value = "https://" + value

        return value
    
class PropertyImageSerializer(serializers.ModelSerializer):

    class Meta:
        model = PropertyImage
        fields = [
            "id",
            "image_s3_key",
            "caption",
            "is_primary"
        ]



class PropertyVideoSerializer(serializers.ModelSerializer):

    class Meta:
        model = PropertyVideo
        fields = [
            "id",
            "video_s3_key",
            "title",
            "is_featured"
        ]



class PropertyDocumentSerializer(serializers.ModelSerializer):

    class Meta:
        model = PropertyDocument
        fields = [
            "id",
            "document_type",
            "title",
            "description"
        ]



from rest_framework import serializers
from .models import (
    Property,
    Amenity,
    FlatType,
    FloorInfo,
    PricingSlab,
    PropertyImage,
    PropertyVideo,
    PropertyDocument
)

class PropertyDetailSerializer(serializers.ModelSerializer):
    amenities = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=Amenity.objects.all(),
        required=False,
        write_only=True
    )
    amenity_details = AmenityCreateSerializer(
        many=True,
        read_only=True,
        source="amenities"
    )
    images = PropertyImageSerializer(
        many=True,
        read_only=True
    )
    videos = PropertyVideoSerializer(
        many=True,
        read_only=True
    )
    documents = PropertyDocumentSerializer(
        many=True,
        read_only=True
    )
    class Meta:
        model = Property
        fields = "__all__"


class FlatTypeCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FlatType
        fields = [
            "id",
            "flat_type",
            "area_sqft",
            "carpet_area",
            "built_up_area",
            "balcony_area",
            "bedrooms",
            "bathrooms",
            "balconies",
            "kitchens",
            "parking_count",
            "description",
            "is_available"
        ]
        read_only_fields = ["id"]


class FloorInfoCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FloorInfo
        fields = [
            "id",
            "floor_number",
            "floor_name",
            "total_units",
            "available_units",
            "expected_completion_date"
        ]
        read_only_fields = ["id"]


class PricingSlabCreateSerializer(serializers.ModelSerializer):
    flat_type = serializers.CharField()
    floor = serializers.IntegerField()
    class Meta:
        model = PricingSlab
        fields = [
            "id",
            "floor",
            "flat_type",
            "base_price",
            "price_per_sqft",
            "booking_amount",
            "discount_percentage",
            "gst_percentage",
            "payment_schedule",
            "additional_charges",
            "is_available"
        ]
        read_only_fields = ["id"]



import json

from rest_framework import serializers

from .models import (
    Property,
    Amenity,
    FlatType,
    FloorInfo,
    PricingSlab,
)


class PropertyCreateSerializer(serializers.ModelSerializer):

    # ---------------------------------------
    # AMENITIES
    # ---------------------------------------

    amenities = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=Amenity.objects.all(),
        required=False
    )

    # ---------------------------------------
    # FLAT TYPES
    # ---------------------------------------

    flat_types = FlatTypeCreateSerializer(
        many=True,
        required=False
    )

    # ---------------------------------------
    # FLOORS
    # ---------------------------------------

    floors = FloorInfoCreateSerializer(
        many=True,
        required=False
    )

    # ---------------------------------------
    # PRICING SLABS
    # ---------------------------------------

    pricing_slabs = PricingSlabCreateSerializer(
        many=True,
        required=False
    )
    google_location_url = serializers.CharField(
    required=False,
    allow_blank=True,
    allow_null=True
    )

    rera_website = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True
    )

    property_website_url = serializers.CharField(
        
        required=False,
        allow_blank=True,
        allow_null=True
    )

    class Meta:

        model = Property

        fields = [
            "title",
            "description",
            "property_type",
            "transaction_type",
            "property_condition",
            "status",
            "city",
            "area",
            "address",
            "landmark",
            "pincode",
            "latitude",
            "longitude",
            "google_location_url",
            "total_area",
            "plot_area",
            "total_floors",
            "total_towers",
            "builder",
            "agent",
            "marketing_partner",
            "amenities",
            "rera_number",
            "rera_qr_code",
            "rera_website",
            "rera_additional_urls",
            "property_website_url",
            "is_under_construction",
            "ready_to_move",
            "possession_date",
            "completion_percentage",
            "features",
            "is_featured",
            "is_verified",
            "is_negotiable",
            "referral_code",

            # Nested data
            "flat_types",
            "floors",
            "pricing_slabs",
        ]
        # =====================================================
    # URL VALIDATION
    # =====================================================

    def validate_google_location_url(self, value):

        if value:
            value = value.strip()

            if value and not value.startswith(("http://", "https://")):
                value = "https://" + value

        return value


    def validate_rera_website(self, value):

        if value:
            value = value.strip()

            if value and not value.startswith(("http://", "https://")):
                value = "https://" + value

        return value


    def validate_property_website_url(self, value):

        if value:
            value = value.strip()

            if value and not value.startswith(("http://", "https://")):
                value = "https://" + value

        return value
    # =====================================================
    # MULTIPART JSON PARSING
    # =====================================================

    def to_internal_value(self, data):

        # ==========================================
        # Convert QueryDict -> normal dict
        # ==========================================

        if hasattr(data, "getlist"):

            original_data = data

            data = {}

            for key in original_data.keys():
                data[key] = original_data.get(key)

        else:
            data = data.copy()

        # ==========================================
        # AMENITIES
        # ==========================================

        amenities = data.get("amenities")

        if isinstance(amenities, str):

            amenities = amenities.strip()

            if amenities:

                try:
                    amenities = json.loads(amenities)

                except json.JSONDecodeError:

                    # Single amenity:
                    # "2"

                    try:
                        amenities = [int(amenities)]

                    except (ValueError, TypeError):

                        raise serializers.ValidationError({
                            "amenities": "Invalid amenities format."
                        })

        # ==========================================
        # Remove extra nested list
        # [[1,2,3]] -> [1,2,3]
        # ==========================================

        if (
            isinstance(amenities, list)
            and len(amenities) == 1
            and isinstance(amenities[0], list)
        ):
            amenities = amenities[0]

        # ==========================================
        # Convert amenity IDs to integers
        # ==========================================

        if isinstance(amenities, list):

            try:
                amenities = [
                    int(amenity)
                    for amenity in amenities
                ]

            except (ValueError, TypeError):

                raise serializers.ValidationError({
                    "amenities": "Amenities must contain valid IDs."
                })

        if amenities is not None:
         data["amenities"] = amenities

        # ==========================================
        # FLAT TYPES / FLOORS / PRICING SLABS
        # ==========================================

        for field in [
            "flat_types",
            "floors",
            "pricing_slabs"
        ]:

            value = data.get(field)

            if isinstance(value, str):

                value = value.strip()

                if value:

                    try:
                        data[field] = json.loads(value)

                    except json.JSONDecodeError:

                        raise serializers.ValidationError({
                            field: "Invalid JSON format."
                        })

        # ==========================================
        # DRF VALIDATION
        # ==========================================

        return super().to_internal_value(data)
    # =====================================================
    # CREATE PROPERTY
    # =====================================================

    def create(self, validated_data):

        # -----------------------------------------------
        # Extract nested data
        # -----------------------------------------------

        amenities = validated_data.pop(
            "amenities",
            []
        )

        flat_types_data = validated_data.pop(
            "flat_types",
            []
        )

        floors_data = validated_data.pop(
            "floors",
            []
        )

        pricing_slabs_data = validated_data.pop(
            "pricing_slabs",
            []
        )

        # -----------------------------------------------
        # CREATE PROPERTY
        # -----------------------------------------------

        property_obj = Property.objects.create(
            **validated_data
        )

        # =================================================
        # AMENITIES
        # =================================================

        if amenities:

            property_obj.amenities.set(
                amenities
            )

        # =================================================
        # FLAT TYPES
        # =================================================

        flat_type_map = {}

        for flat_data in flat_types_data:

            flat_type_obj = FlatType.objects.create(
                property=property_obj,
                **flat_data
            )

            # Map using flat_type value
            flat_type_map[
                flat_type_obj.flat_type
            ] = flat_type_obj

        # =================================================
        # FLOORS
        # =================================================

        floor_map = {}

        for floor_data in floors_data:

            floor_obj = FloorInfo.objects.create(
                property=property_obj,
                **floor_data
            )

            # Map using floor_number
            floor_map[
                floor_obj.floor_number
            ] = floor_obj

        # =================================================
        # PRICING SLABS
        # =================================================

        for pricing_data in pricing_slabs_data:

            pricing_data = pricing_data.copy()

            # -------------------------------------------
            # Get flat type
            # -------------------------------------------

            flat_type_name = pricing_data.pop(
                "flat_type",
                None
            )

            # -------------------------------------------
            # Get floor
            # -------------------------------------------

            floor_number = pricing_data.pop(
                "floor",
                None
            )

            # -------------------------------------------
            # Find flat type
            # -------------------------------------------

            flat_type_obj = flat_type_map.get(
                flat_type_name
            )

            if not flat_type_obj:

                raise serializers.ValidationError({
                    "pricing_slabs": [
                        f"Flat type '{flat_type_name}' not found."
                    ]
                })

            # -------------------------------------------
            # Find floor
            # -------------------------------------------

            floor_obj = floor_map.get(
                floor_number
            )

            if not floor_obj:

                raise serializers.ValidationError({
                    "pricing_slabs": [
                        f"Floor '{floor_number}' not found."
                    ]
                })

            # -------------------------------------------
            # Create Pricing Slab
            # -------------------------------------------

            PricingSlab.objects.create(
                property=property_obj,
                flat_type=flat_type_obj,
                floor=floor_obj,
                **pricing_data
            )

        # -----------------------------------------------
        # RETURN PROPERTY
        # -----------------------------------------------

        return property_obj
    
class PropertyEnquiryCreateSerializer(serializers.ModelSerializer):

    property_details = PropertyDetailSerializer(
        source="property",
        read_only=True
    )

    class Meta:
        model = PropertyEnquiry
        fields = [
            "id",
            "property",
            "customer_name",
            "customer_email",
            "customer_mobile",
            "message",
            "status",
            "flat_type",
            "budget_min",
            "budget_max",
            "assigned_channel_partner",
            "assigned_at",
            "followup_date",
            "created_at",
            "updated_at",
            "property_details",   # comma added
        ]

        read_only_fields = [
            "id",
            "status",
            "assigned_channel_partner",
            "assigned_at",
            "created_at",
            "updated_at",
            "property_details",
        ]

    def validate_customer_mobile(self, value):

        if not value.isdigit():
            raise serializers.ValidationError(
                "Enter a valid mobile number."
            )

        if len(value) != 10:
            raise serializers.ValidationError(
                "Mobile number must be 10 digits."
            )

        return value

               
    
class PropertyEnquiryFilterSerializer(serializers.Serializer):
    property = serializers.IntegerField(required=False)
    assigned_agent = serializers.IntegerField(required=False)
    customer_name = serializers.CharField(required=False)
    status = serializers.CharField(required=False)
    search = serializers.CharField(required=False)    
    
    
from rest_framework import serializers
from .models import RealEstateChannelPartner


class RealEstateChannelPartnerSerializer(serializers.ModelSerializer):

    class Meta:
        model = RealEstateChannelPartner
        fields = [
            'id',
            'user',
            'name',
            'company_name',
            'mobile',
            'email',
            'address',
            'city',
            'state',
            'pincode',
            'cp_code',
            'rera_number',
            'commission_percentage',
            'status',
            'notes',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'created_at',
            'updated_at',
        ]

    def validate_cp_code(self, value):
        value = value.strip().upper()

        if RealEstateChannelPartner.objects.filter(
            cp_code=value
        ).exists():
            raise serializers.ValidationError(
                "CP Code already exists."
            )

        return value

    def validate_mobile(self, value):
        value = value.strip()

        if RealEstateChannelPartner.objects.filter(
            mobile=value
        ).exists():
            raise serializers.ValidationError(
                "Mobile number already exists."
            )

        return value    
    
    
    
from rest_framework import serializers
from .models import RealEstatePropertyCommission


class RealEstatePropertyCommissionSerializer(
    serializers.ModelSerializer
):

    class Meta:
        model = RealEstatePropertyCommission

        fields = [
            'id',
            'property',
            'channel_partner',
            'sale_price',
            'cp_commission_percentage',
            'cp_commission_amount',
            'business_partner_percentage',
            'business_partner_amount',
            'cp_final_amount',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'cp_commission_percentage',
            'cp_commission_amount',
            'business_partner_amount',
            'cp_final_amount',
            'created_at',
            'updated_at',
        ]    
        
class PricingSlabListSerializer(serializers.ModelSerializer):

    floor = serializers.IntegerField(
        source="floor.floor_number"
    )

    flat_type = serializers.CharField(
        source="flat_type.flat_type"
    )

    class Meta:
        model = PricingSlab
        fields = [
            "id",
            "floor",
            "flat_type",
            "base_price",
            "price_per_sqft",
            "booking_amount",
            "discount_percentage",
            "gst_percentage",
            "payment_schedule",
            "additional_charges",
            "is_available",
        ]        
        


class ApprovedPropertyListSerializer(serializers.ModelSerializer):

    amenities = AmenityCreateSerializer(
        many=True,
        read_only=True
    )

    flat_types = FlatTypeCreateSerializer(
        many=True,
        read_only=True
    )

    floors = FloorInfoCreateSerializer(
        many=True,
        read_only=True
    )

    pricing_slabs = PricingSlabListSerializer(
        many=True,
        read_only=True
    )

    builder = BuilderSerializer(
        read_only=True
    )

    images = PropertyImageSerializer(
        many=True,
    )

    videos = PropertyVideoSerializer(
        many=True,
        read_only=True
    )

    # Subscription
    subscription_required = serializers.SerializerMethodField()

    class Meta:
        model = Property
        fields = [
            "id",
            "title",
            "slug",
            "description",
            "property_type",
            "transaction_type",
            "status",
            "status_approved",

            "city",
            "area",
            "address",
            "landmark",
            "pincode",
            "latitude",
            "longitude",
            "google_location_url",

            "total_area",
            "plot_area",
            "total_floors",
            "total_towers",

            # Builder
            "builder",

            # Amenities
            "amenities",

            # Images / Videos
            "images",
            "videos",

            "rera_number",
            "rera_qr_code",
            "rera_website",
            "rera_additional_urls",

            "property_website_url",
            "is_under_construction",
            "possession_date",
            "completion_percentage",
            "features",

            "is_featured",
            "is_verified",
            "is_negotiable",

            "referral_code",

            "flat_types",
            "floors",
            "pricing_slabs",

            "created_at",
            "updated_at",
            "published_at",
            "expiry_date",

            # Subscription
            "source",
            "free_days",
            "free_expiry_date",
            "subscription_required",
            "subscription_active",
        ]

    def get_subscription_required(self, obj):

        return check_property_subscription(obj)