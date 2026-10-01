from rest_framework import serializers

from .models import (
    BazaarCategory,
    BazaarSubCategory,
    BazaarAttribute,
    BazaarListing,
    BazaarListingImage,
    BazaarPlan,
    BazaarPricing,
)

class BazaarCategoryCreateSerializer(serializers.ModelSerializer):

    class Meta:
        model = BazaarCategory
        fields = [
            "name",
            "slug",
            "description",
            "is_active",
            "sort_order",
        ]

    def validate_name(self, value):
        return value.strip()

    def validate_slug(self, value):
        return value.strip().lower()
class BazaarAttributeSerializer(serializers.ModelSerializer):

    class Meta:
        model = BazaarAttribute
        fields = [
            "id",
            "name",
            "key",
            "field_type",
            "options",
            "is_required",
            "sort_order",
        ]


class BazaarSubCategorySerializer(serializers.ModelSerializer):

    attributes = serializers.SerializerMethodField()

    class Meta:
        model = BazaarSubCategory
        fields = [
            "id",
            "name",
            "slug",
            "attributes",
        ]

    def get_attributes(self, obj):
        return BazaarAttributeSerializer(obj.attributes.filter(is_active=True), many=True).data


class BazaarCategorySerializer(serializers.ModelSerializer):

    subcategories = serializers.SerializerMethodField()
    attributes = serializers.SerializerMethodField()

    class Meta:
        model = BazaarCategory
        fields = [
            "id",
            "name",
            "slug",
            "description",
            "subcategories",
            "attributes",
        ]

    def get_subcategories(self, obj):
        return BazaarSubCategorySerializer(obj.subcategories.filter(is_active=True), many=True).data

    def get_attributes(self, obj):
        return BazaarAttributeSerializer(obj.attributes.filter(subcategory__isnull=True, is_active=True), many=True).data


class BazaarListingImageSerializer(serializers.ModelSerializer):

    class Meta:
        model = BazaarListingImage
        fields = [
            "id",
            "image_s3_key",
            "is_primary",
            "sort_order",
        ]


class BazaarListingSerializer(serializers.ModelSerializer):

    images = BazaarListingImageSerializer(many=True, read_only=True)
    category_name = serializers.CharField(source="category.name", read_only=True)
    subcategory_name = serializers.CharField(source="subcategory.name", read_only=True)
    username = serializers.CharField(source="user.name", read_only=True)

    class Meta:
        model = BazaarListing
        fields = [
            "id",
            "title",
            "description",
            "price",
            "is_negotiable",
            "condition",
            "seller_type",
            "category",
            "category_name",
            "subcategory",
            "subcategory_name",
            "city",
            "area",
            "address",
            "pincode",
            "latitude",
            "longitude",
            "attributes",
            "status",
            "is_featured",
            "views_count",
            "favourites_count",
            "is_first_listing",
            "free_period_days",
            "active_from",
            "expires_at",
            "username",
            "images",
            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "status",
            "is_first_listing",
            "free_period_days",
            "active_from",
            "expires_at",
            "views_count",
            "favourites_count",
            "user",
        ]

    def validate(self, attrs):

        category = attrs.get("category")
        subcategory = attrs.get("subcategory")

        if subcategory:
            if not category:
                raise serializers.ValidationError({
                    "category": "Category is required when selecting a subcategory."
                })

            if subcategory.category_id != category.id:
                raise serializers.ValidationError({
                    "subcategory": "Selected subcategory does not belong to selected category."
                })

        return attrs


class BazaarPlanSerializer(serializers.ModelSerializer):

    class Meta:
        model = BazaarPlan
        fields = [
            "id",
            "name",
            "duration_days",
            "description",
        ]


class BazaarPricingSerializer(serializers.ModelSerializer):

    plan_name = serializers.CharField(source="plan.name", read_only=True)

    class Meta:
        model = BazaarPricing
        fields = [
            "id",
            "category",
            "plan",
            "plan_name",
            "price",
        ]
        
class BazaarSubCategoryCreateSerializer(serializers.ModelSerializer):

    class Meta:
        model = BazaarSubCategory
        fields = [
            "id",
            "category",
            "name",
            "slug",
            "is_active",
            "sort_order",
        ]

    def validate(self, attrs):

        category = attrs.get("category")
        slug = attrs.get("slug")

        if BazaarSubCategory.objects.filter(
            category=category,
            slug=slug
        ).exists():
            raise serializers.ValidationError({
                "slug": "This subcategory already exists under this category."
            })

        return attrs        
    
    
class BazaarSubCategoryListSerializer(serializers.ModelSerializer):

    class Meta:
        model = BazaarSubCategory
        fields = [
            "id",
            "category",
            "name",
            "slug",
            "is_active",
            "sort_order",
            "created_at",
        ]    
        
        
        
class BazaarAttributeCreateSerializer(serializers.ModelSerializer):

    category_id = serializers.IntegerField(write_only=True)
    subcategory_id = serializers.IntegerField(
        write_only=True,
        required=False,
        allow_null=True
    )

    class Meta:
        model = BazaarAttribute

        fields = [
            "id",
            "category_id",
            "subcategory_id",
            "name",
            "key",
            "field_type",
            "options",
            "is_required",
            "is_active",
            "sort_order",
        ]

    def validate(self, attrs):

        category_id = attrs.pop("category_id")
        subcategory_id = attrs.pop("subcategory_id", None)

        # -----------------------------------------
        # CATEGORY
        # -----------------------------------------

        try:
            category = BazaarCategory.objects.get(
                id=category_id,
                is_active=True
            )
        except BazaarCategory.DoesNotExist:
            raise serializers.ValidationError({
                "category_id": "Category not found."
            })

        # -----------------------------------------
        # SUBCATEGORY
        # -----------------------------------------

        subcategory = None

        if subcategory_id is not None:

            try:
                subcategory = BazaarSubCategory.objects.get(
                    id=subcategory_id,
                    category=category,
                    is_active=True
                )
            except BazaarSubCategory.DoesNotExist:
                raise serializers.ValidationError({
                    "subcategory_id":
                    "Subcategory not found for this category."
                })

        # -----------------------------------------
        # DUPLICATE KEY CHECK
        # -----------------------------------------

        if BazaarAttribute.objects.filter(
            category=category,
            subcategory=subcategory,
            key=attrs.get("key")
        ).exists():

            raise serializers.ValidationError({
                "key": "This attribute already exists."
            })

        attrs["category"] = category
        attrs["subcategory"] = subcategory

        return attrs        
        
class BazaarListingCreateSerializer(serializers.ModelSerializer):

    category_id = serializers.IntegerField(write_only=True)
    subcategory_id = serializers.IntegerField(
        write_only=True,
        required=False,
        allow_null=True
    )

    class Meta:
        model = BazaarListing

        fields = [
            "category_id",
            "subcategory_id",
            "title",
            "description",
            "price",
            "is_negotiable",
            "condition",
            "seller_type",
            "city",
            "area",
            "address",
            "pincode",
            "latitude",
            "longitude",
            "attributes",
            "status",
        ]

    def validate(self, attrs):

        category_id = attrs.pop("category_id")
        subcategory_id = attrs.pop("subcategory_id", None)

        # =========================
        # CATEGORY VALIDATION
        # =========================
        try:
            category = BazaarCategory.objects.get(
                id=category_id,
                is_active=True
            )
        except BazaarCategory.DoesNotExist:
            raise serializers.ValidationError({
                "category_id": "Category not found."
            })

        # =========================
        # SUBCATEGORY VALIDATION
        # =========================
        subcategory = None

        if subcategory_id:

            try:
                subcategory = BazaarSubCategory.objects.get(
                    id=subcategory_id,
                    category=category,
                    is_active=True
                )
            except BazaarSubCategory.DoesNotExist:
                raise serializers.ValidationError({
                    "subcategory_id": "Subcategory not found for this category."
                })

        attrs["category"] = category
        attrs["subcategory"] = subcategory

        return attrs
    
    
class BazaarListingUpdateSerializer(serializers.ModelSerializer):

    category_id = serializers.IntegerField(
        write_only=True,
        required=False
    )

    subcategory_id = serializers.IntegerField(
        write_only=True,
        required=False,
        allow_null=True
    )

    class Meta:
        model = BazaarListing

        fields = [
            "category_id",
            "subcategory_id",
            "title",
            "description",
            "price",
            "is_negotiable",
            "condition",
            "seller_type",
            "city",
            "area",
            "address",
            "pincode",
            "latitude",
            "longitude",
            "attributes",
            "status",
        ]

    def validate(self, attrs):

        category_id = attrs.pop(
            "category_id",
            None
        )

        subcategory_id = attrs.pop(
            "subcategory_id",
            None
        )

        # =====================================
        # EXISTING CATEGORY
        # =====================================

        if category_id is not None:

            try:

                category = BazaarCategory.objects.get(
                    id=category_id,
                    is_active=True
                )

            except BazaarCategory.DoesNotExist:

                raise serializers.ValidationError({
                    "category_id": "Category not found."
                })

        else:

            category = self.instance.category

        # =====================================
        # SUBCATEGORY
        # =====================================

        if subcategory_id is not None:

            if subcategory_id:

                try:

                    subcategory = BazaarSubCategory.objects.get(
                        id=subcategory_id,
                        category=category,
                        is_active=True
                    )

                except BazaarSubCategory.DoesNotExist:

                    raise serializers.ValidationError({
                        "subcategory_id":
                        "Subcategory not found for this category."
                    })

            else:

                subcategory = None

        else:

            subcategory = self.instance.subcategory

        # =====================================
        # ASSIGN
        # =====================================

        attrs["category"] = category
        attrs["subcategory"] = subcategory

        return attrs    
    
class BazaarListingImageSerializer(serializers.ModelSerializer):

    image_url = serializers.SerializerMethodField()

    class Meta:
        model = BazaarListingImage
        fields = [
            "id",
            "image_s3_key",
            "image_url",
            "is_primary",
            "sort_order",
        ]

    def get_image_url(self, obj):

        from .s3_upload import get_bazaar_image_url

        return get_bazaar_image_url(
            obj.image_s3_key
        )


class BazaarListingListSerializer(serializers.ModelSerializer):

    user_id = serializers.IntegerField(
        source="user.id",
        read_only=True
    )

    category_id = serializers.IntegerField(
        source="category.id",
        read_only=True
    )

    category_name = serializers.CharField(
        source="category.name",
        read_only=True
    )

    subcategory_id = serializers.IntegerField(
        source="subcategory.id",
        read_only=True,
        allow_null=True
    )

    subcategory_name = serializers.CharField(
        source="subcategory.name",
        read_only=True,
        allow_null=True
    )

    images = BazaarListingImageSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = BazaarListing

        fields = [
            "id",
            "user_id",

            "category_id",
            "category_name",

            "subcategory_id",
            "subcategory_name",

            "title",
            "description",
            "price",
            "is_negotiable",
            "condition",
            "seller_type",

            "city",
            "area",
            "address",
            "pincode",

            "latitude",
            "longitude",

            "attributes",

            "status",

            "is_featured",
            "views_count",
            "favourites_count",

            "is_first_listing",
            "free_period_days",

            "active_from",
            "expires_at",

            "created_at",
            "updated_at",

            "images",
        ]    