from rest_framework import serializers

from .models import (
    BazaarCategory,
    BazaarSubCategory,
    BazaarAttribute,
    BazaarListing,
    BazaarListingImage,
    BazaarPlan,
    BazaarPricing,

    BazaarCommunicationPlan,
    BazaarCommunicationSettings,
    BazaarCommunicationSubscription,
    BazaarCommunicationUsage,

    BazaarChat,
    BazaarChatMessage,
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
            "user_id",
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












##############################################################################
##############################################################################
#            OLX ENQUIRY AND QNX CHAT SUBCRIPTION PLAN SERIALIZERS
##############################################################################
##############################################################################


class BazaarCommunicationPlanSerializer(serializers.ModelSerializer):
    """
    Used by admin APIs to create, update and list communication plans.
    """

    class Meta:
        model = BazaarCommunicationPlan
        fields = [
            "id",
            "name",
            "description",
            "price",
            "currency",
            "duration_days",
            "chat_limit",
            "chat_unlimited",
            "chat_limit_period",
            "enquiry_limit",
            "enquiry_unlimited",
            "enquiry_limit_period",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
        ]

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError(
                "Plan name cannot be empty."
            )
        return value

    def validate_currency(self, value):
        return value.upper()

    def validate(self, attrs):
        """
        A zero limit is permitted when the corresponding feature is
        unlimited. Otherwise, zero means no usage is included.
        """
        chat_unlimited = attrs.get(
            "chat_unlimited",
            getattr(self.instance, "chat_unlimited", False),
        )
        enquiry_unlimited = attrs.get(
            "enquiry_unlimited",
            getattr(self.instance, "enquiry_unlimited", False),
        )

        chat_limit = attrs.get(
            "chat_limit",
            getattr(self.instance, "chat_limit", 0),
        )
        enquiry_limit = attrs.get(
            "enquiry_limit",
            getattr(self.instance, "enquiry_limit", 0),
        )

        if chat_unlimited and chat_limit:
            raise serializers.ValidationError({
                "chat_limit": (
                    "Set chat_limit to 0 when chat_unlimited is true."
                )
            })

        if enquiry_unlimited and enquiry_limit:
            raise serializers.ValidationError({
                "enquiry_limit": (
                    "Set enquiry_limit to 0 when "
                    "enquiry_unlimited is true."
                )
            })

        return attrs


class BazaarCommunicationSettingsSerializer(
    serializers.ModelSerializer
):
    """
    Used to retrieve and update global communication settings.
    """

    class Meta:
        model = BazaarCommunicationSettings
        fields = [
            "id",
            "chat_mode",
            "enquiry_mode",
            "free_chat_limit",
            "free_chat_period",
            "free_enquiry_limit",
            "free_enquiry_period",
            "block_contact_info",
            "block_phone_numbers",
            "block_emails",
            "block_social_handles",
            "block_external_links",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
        ]

    def validate(self, attrs):
        chat_mode = attrs.get(
            "chat_mode",
            getattr(self.instance, "chat_mode", None),
        )
        enquiry_mode = attrs.get(
            "enquiry_mode",
            getattr(self.instance, "enquiry_mode", None),
        )

        free_chat_limit = attrs.get(
            "free_chat_limit",
            getattr(self.instance, "free_chat_limit", 0),
        )
        free_enquiry_limit = attrs.get(
            "free_enquiry_limit",
            getattr(self.instance, "free_enquiry_limit", 0),
        )

        modes_with_free_allowance = {
            BazaarCommunicationSettings.AccessMode.FREE_WITH_LIMIT,
            BazaarCommunicationSettings.AccessMode.MIXED,
        }

        if (
            chat_mode in modes_with_free_allowance
            and free_chat_limit < 1
        ):
            raise serializers.ValidationError({
                "free_chat_limit": (
                    "The free chat limit must be at least 1 "
                    "for this mode."
                )
            })

        if (
            enquiry_mode in modes_with_free_allowance
            and free_enquiry_limit < 1
        ):
            raise serializers.ValidationError({
                "free_enquiry_limit": (
                    "The free enquiry limit must be at least 1 "
                    "for this mode."
                )
            })

        return attrs


class BazaarCommunicationSubscriptionSerializer(
    serializers.ModelSerializer
):
    """
    Read-only subscription details for the authenticated user.
    """

    plan_name = serializers.CharField(
        source="plan.name",
        read_only=True,
    )

    is_currently_valid = serializers.BooleanField(read_only=True)

    class Meta:
        model = BazaarCommunicationSubscription
        fields = [
            "id",
            "plan",
            "plan_name",
            "starts_at",
            "expires_at",
            "status",
            "price_paid",
            "currency",
            "chat_limit_snapshot",
            "chat_unlimited_snapshot",
            "chat_limit_period_snapshot",
            "enquiry_limit_snapshot",
            "enquiry_unlimited_snapshot",
            "enquiry_limit_period_snapshot",
            "is_currently_valid",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class BazaarCommunicationUsageSerializer(
    serializers.ModelSerializer
):
    """
    Read-only usage records. Clients cannot change their own usage counts.
    """

    subscription_id = serializers.IntegerField(
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = BazaarCommunicationUsage
        fields = [
            "id",
            "subscription_id",
            "feature",
            "period_start",
            "period_end",
            "used_count",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields






##############################################################################
##############################################################################
#                      QNX CHAT SERIALIZERS
##############################################################################
##############################################################################

class BazaarChatCreateSerializer(serializers.Serializer):
    other_user_id = serializers.IntegerField(min_value=1)
    listing_id = serializers.IntegerField(
        min_value=1,
        required=False,
        allow_null=True,
    )

class BazaarChatMessageCreateSerializer(serializers.Serializer):
    message = serializers.CharField(
        max_length=5000,
        trim_whitespace=True,
        allow_blank=False,
    )

class BazaarChatMessageSerializer(serializers.ModelSerializer):
    sender_id = serializers.IntegerField(read_only=True)

    class Meta:
        model = BazaarChatMessage
        fields = [
            "id",
            "chat",
            "sender_id",
            "message",
            "moderation_status",
            "is_read",
            "read_at",
            "created_at",
        ]
        read_only_fields = fields

class BazaarChatSerializer(serializers.ModelSerializer):
    other_user_id = serializers.SerializerMethodField()
    other_username = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = BazaarChat
        fields = [
            "id",
            "user_one",
            "user_two",
            "other_user_id",
            "other_username",
            "listing",
            "is_active",
            "last_message",
            "unread_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_other_user_id(self, obj):
        request = self.context.get("request")
        if not request:
            return None
        other_user = obj.get_other_participant(request.user)
        return other_user.pk if other_user else None

    def get_other_username(self, obj):
        request = self.context.get("request")
        if not request:
            return None
        other_user = obj.get_other_participant(request.user)
        if not other_user:
            return None
        return other_user.get_username()

    def get_last_message(self, obj):
        message = (
            obj.messages
            .filter(is_active=True)
            .order_by("-created_at")
            .first()
        )
        if not message:
            return None
        return BazaarChatMessageSerializer(message).data

    def get_unread_count(self, obj):
        request = self.context.get("request")
        if not request:
            return 0
        return obj.messages.filter(
            is_active=True,
            is_read=False,
        ).exclude(
            sender=request.user,
        ).count()