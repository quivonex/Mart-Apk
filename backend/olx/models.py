# olx.models.py

from django.db import models
from django.conf import settings
from django.utils import timezone
from django.core.validators import MinValueValidator
from django.db.models import Q



class BazaarCategory(models.Model):

    name = models.CharField(max_length=150, unique=True)
    slug = models.SlugField(max_length=180, unique=True)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "bazaar_categories"
        ordering = ["sort_order", "name"]

    def __str__(self):
        return self.name


class BazaarSubCategory(models.Model):

    category = models.ForeignKey(BazaarCategory, on_delete=models.CASCADE, related_name="subcategories")
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=180)
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "bazaar_subcategories"
        ordering = ["sort_order", "name"]
        constraints = [
            models.UniqueConstraint(fields=["category", "slug"], name="unique_bazaar_subcategory")
        ]

    def __str__(self):
        return f"{self.category.name} - {self.name}"


class BazaarAttribute(models.Model):

    FIELD_TYPES = (
        ("text", "Text"),
        ("number", "Number"),
        ("select", "Select"),
        ("boolean", "Boolean"),
        ("year", "Year"),
    )

    category = models.ForeignKey(BazaarCategory, on_delete=models.CASCADE, related_name="attributes")
    subcategory = models.ForeignKey(BazaarSubCategory, on_delete=models.CASCADE, related_name="attributes", null=True, blank=True)
    name = models.CharField(max_length=150)
    key = models.SlugField(max_length=150)
    field_type = models.CharField(max_length=20, choices=FIELD_TYPES, default="text")
    options = models.JSONField(default=list, blank=True)
    is_required = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = "bazaar_attributes"

    def __str__(self):
        return self.name


class BazaarListing(models.Model):

    CONDITION_CHOICES = (
        ("new", "New"),
        ("like_new", "Like New"),
        ("good", "Good"),
        ("fair", "Fair"),
        ("used", "Used"),
    )

    STATUS_CHOICES = (
        ("draft", "Draft"),
        ("active", "Active"),
        ("expired", "Expired"),
        ("sold", "Sold"),
        ("inactive", "Inactive"),
        ("pending", "Pending"),
    )

    SELLER_TYPE_CHOICES = (
        ("individual", "Individual"),
        ("business", "Business"),
    )

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="bazaar_listings")
    category = models.ForeignKey(BazaarCategory, on_delete=models.PROTECT, related_name="listings")
    subcategory = models.ForeignKey(BazaarSubCategory, on_delete=models.PROTECT, related_name="listings", null=True, blank=True)
    title = models.CharField(max_length=250)
    description = models.TextField()
    price = models.DecimalField(max_digits=14, decimal_places=2)
    is_negotiable = models.BooleanField(default=True)
    condition = models.CharField(max_length=30, choices=CONDITION_CHOICES, default="used")
    seller_type = models.CharField(max_length=30, choices=SELLER_TYPE_CHOICES, default="individual")
    city = models.CharField(max_length=100)
    area = models.CharField(max_length=150, blank=True)
    address = models.TextField(blank=True)
    pincode = models.CharField(max_length=10, blank=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    attributes = models.JSONField(default=dict, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="draft")
    is_featured = models.BooleanField(default=False)
    views_count = models.PositiveIntegerField(default=0)
    favourites_count = models.PositiveIntegerField(default=0)
    is_first_listing = models.BooleanField(default=False)
    free_period_days = models.PositiveIntegerField(default=0)
    active_from = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "bazaar_listings"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["category", "status"]),
            models.Index(fields=["subcategory", "status"]),
            models.Index(fields=["city", "status"]),
            models.Index(fields=["expires_at"]),
        ]

    def __str__(self):
        return self.title

    @property
    def is_expired(self):
        if not self.expires_at:
            return False
        return timezone.now() >= self.expires_at


class BazaarListingImage(models.Model):

    listing = models.ForeignKey(BazaarListing, on_delete=models.CASCADE, related_name="images")
    image_s3_key = models.CharField(max_length=500)
    is_primary = models.BooleanField(default=False)
    sort_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "bazaar_listing_images"
        ordering = ["sort_order", "id"]


class BazaarPlan(models.Model):

    name = models.CharField(max_length=100)
    duration_days = models.PositiveIntegerField()
    # price = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "bazaar_plans"
        ordering = ["sort_order", "name"]

    def __str__(self):
        return f"{self.name}"


class BazaarPricing(models.Model):

    category = models.ForeignKey(BazaarCategory, on_delete=models.CASCADE, related_name="pricing")
    plan = models.ForeignKey(BazaarPlan, on_delete=models.CASCADE, related_name="category_pricing")
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "bazaar_pricing"
        constraints = [
            models.UniqueConstraint(fields=["category", "plan"], name="unique_bazaar_category_plan")
        ]

    def __str__(self):
        return f"{self.category.name} - {self.plan.name}"


class BazaarSettings(models.Model):

    first_listing_free = models.BooleanField(default=True)
    free_listing_days = models.PositiveIntegerField(default=15)
    payment_required_after_expiry = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "bazaar_settings"

    def __str__(self):
        return "Old Bazaar Settings"


class BazaarPayment(models.Model):

    STATUS_CHOICES = (
        ("created", "Created"),
        ("paid", "Paid"),
        ("failed", "Failed"),
        ("refunded", "Refunded"),
    )

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="bazaar_payments")
    listing = models.ForeignKey(BazaarListing, on_delete=models.CASCADE, related_name="payments")
    plan = models.ForeignKey(BazaarPlan, on_delete=models.PROTECT)
    razorpay_order_id = models.CharField(max_length=150, unique=True)
    razorpay_payment_id = models.CharField(max_length=150, blank=True, null=True)
    razorpay_signature = models.CharField(max_length=500, blank=True, null=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="created")
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "bazaar_payments"


class BazaarRenewal(models.Model):

    listing = models.ForeignKey(BazaarListing, on_delete=models.CASCADE, related_name="renewals")
    payment = models.OneToOneField(BazaarPayment, on_delete=models.PROTECT, related_name="renewal")
    old_expiry = models.DateTimeField()
    new_expiry = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "bazaar_renewals"
        
        
        
        
        
class BazaarEnquiry(models.Model):

    STATUS_CHOICES = (("new", "New"),("contacted", "Contacted"),("closed", "Closed"),)
    listing = models.ForeignKey(BazaarListing,on_delete=models.CASCADE,related_name="enquiries")
    user = models.ForeignKey(settings.AUTH_USER_MODEL,on_delete=models.CASCADE,related_name="bazaar_enquiries")
    message = models.TextField()
    phone_number = models.CharField(max_length=20,blank=True,null=True)
    status = models.CharField(max_length=20,choices=STATUS_CHOICES,default="new")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    class Meta:
        db_table = "bazaar_enquiries"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.listing.title} - {self.user}"        



















##############################################################################
##############################################################################
#            OLX ENQUIRY AND QNX CHAT SUBCRIPTION PLAN MODELS
##############################################################################
##############################################################################


class BazaarCommunicationPlan(models.Model):
    """
    Admin-managed plan for both chat and enquiry usage.
    """

    class LimitPeriod(models.TextChoices):
        DAILY = "daily", "Daily"
        WEEKLY = "weekly", "Weekly"
        MONTHLY = "monthly", "Monthly"
        SUBSCRIPTION = "subscription", "For Subscription Duration"

    name = models.CharField(max_length=150, unique=True)
    description = models.TextField(blank=True)

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )
    currency = models.CharField(max_length=3, default="INR")
    duration_days = models.PositiveIntegerField(
        validators=[MinValueValidator(1)]
    )

    # Chat entitlements
    chat_limit = models.PositiveIntegerField(default=0)
    chat_unlimited = models.BooleanField(default=False)
    chat_limit_period = models.CharField(
        max_length=20,
        choices=LimitPeriod.choices,
        default=LimitPeriod.SUBSCRIPTION,
    )

    # Enquiry entitlements
    enquiry_limit = models.PositiveIntegerField(default=0)
    enquiry_unlimited = models.BooleanField(default=False)
    enquiry_limit_period = models.CharField(
        max_length=20,
        choices=LimitPeriod.choices,
        default=LimitPeriod.SUBSCRIPTION,
    )

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["price", "name"]
        indexes = [
            models.Index(fields=["is_active", "price"]),
        ]

    def __str__(self):
        return f"{self.name} - {self.currency} {self.price}"



class BazaarCommunicationSubscription(models.Model):
    """
    One record per communication subscription purchase.

    Purchased plan entitlements and duration are snapshotted so later
    edits to the original plan do not change existing subscriptions.
    """

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACTIVE = "active", "Active"
        EXPIRED = "expired", "Expired"
        FAILED = "failed", "Failed"
        CANCELLED = "cancelled", "Cancelled"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="bazaar_communication_subscriptions",
    )

    plan = models.ForeignKey(
        BazaarCommunicationPlan,
        on_delete=models.PROTECT,
        related_name="subscriptions",
    )

    starts_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )

    price_paid = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )

    currency = models.CharField(max_length=3, default="INR")

    # Snapshot of the purchased subscription duration
    duration_days_snapshot = models.PositiveIntegerField(
        validators=[MinValueValidator(1)],
        null=True,
        blank=True,
    )

    # Purchased chat entitlement snapshot
    chat_limit_snapshot = models.PositiveIntegerField(default=0)
    chat_unlimited_snapshot = models.BooleanField(default=False)

    chat_limit_period_snapshot = models.CharField(
        max_length=20,
        choices=BazaarCommunicationPlan.LimitPeriod.choices,
        default=BazaarCommunicationPlan.LimitPeriod.SUBSCRIPTION,
    )

    # Purchased enquiry entitlement snapshot
    enquiry_limit_snapshot = models.PositiveIntegerField(default=0)
    enquiry_unlimited_snapshot = models.BooleanField(default=False)

    enquiry_limit_period_snapshot = models.CharField(
        max_length=20,
        choices=BazaarCommunicationPlan.LimitPeriod.choices,
        default=BazaarCommunicationPlan.LimitPeriod.SUBSCRIPTION,
    )

    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(
                fields=["user", "status", "is_active"]
            ),
            models.Index(
                fields=["expires_at"]
            ),
        ]
        constraints = [
            models.CheckConstraint(
                condition=(
                    Q(expires_at__isnull=True)
                    | Q(starts_at__isnull=True)
                    | Q(expires_at__gt=models.F("starts_at"))
                ),
                name="bazaar_comm_expiry_after_start",
            ),
        ]

    def __str__(self):
        return (
            f"{self.user} - {self.plan.name} "
            f"({self.status})"
        )

    @property
    def is_currently_valid(self):
        now = timezone.now()

        return (
            self.is_active
            and self.status == self.Status.ACTIVE
            and self.starts_at is not None
            and self.starts_at <= now
            and self.expires_at is not None
            and self.expires_at > now
        )


class BazaarCommunicationUsage(models.Model):
    """
    Tracks usage independently for each user, feature and subscription.

    subscription=None represents free usage.
    Paid usage is linked to the subscription whose allowance is consumed.
    """

    class Feature(models.TextChoices):
        CHAT = "chat", "Chat"
        ENQUIRY = "enquiry", "Enquiry"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="bazaar_communication_usage",
    )
    subscription = models.ForeignKey(
        BazaarCommunicationSubscription,
        on_delete=models.PROTECT,
        related_name="usage_records",
        null=True,
        blank=True,
    )

    feature = models.CharField(
        max_length=20,
        choices=Feature.choices,
    )

    # The exact window for which used_count applies.
    # For subscription-duration limits, use the subscription's start/end.
    period_start = models.DateTimeField()
    period_end = models.DateTimeField()

    used_count = models.PositiveIntegerField(default=0)

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-period_start"]
        indexes = [
            models.Index(
                fields=["user", "feature", "period_start", "period_end"]
            ),
            models.Index(
                fields=["subscription", "feature", "period_start"]
            ),
        ]
        constraints = [
            models.CheckConstraint(
                condition=Q(period_end__gt=models.F("period_start")),
                name="bazaar_usage_period_valid",
            ),
            models.CheckConstraint(
                condition=Q(used_count__gte=0),
                name="bazaar_usage_count_nonnegative",
            ),
        ]

    def __str__(self):
        source = (
            f"Subscription {self.subscription_id}"
            if self.subscription_id
            else "Free usage"
        )
        return (
            f"{self.user} - {self.feature} - "
            f"{source} - {self.used_count}"
        )


class BazaarCommunicationSettings(models.Model):
    """
    Global configuration for communication access and contact restrictions.

    Keep one active settings record for the application.
    """

    class AccessMode(models.TextChoices):
        FREE = "free", "Free"
        FREE_WITH_LIMIT = "free_with_limit", "Free With Limit"
        SUBSCRIPTION_REQUIRED = (
            "subscription_required",
            "Subscription Required",
        )
        MIXED = "mixed", "Free Allowance Then Subscription"

    class FreePeriod(models.TextChoices):
        DAILY = "daily", "Daily"
        WEEKLY = "weekly", "Weekly"
        MONTHLY = "monthly", "Monthly"

    chat_mode = models.CharField(
        max_length=30,
        choices=AccessMode.choices,
        default=AccessMode.FREE_WITH_LIMIT,
    )
    enquiry_mode = models.CharField(
        max_length=30,
        choices=AccessMode.choices,
        default=AccessMode.FREE_WITH_LIMIT,
    )

    free_chat_limit = models.PositiveIntegerField(default=5)
    free_chat_period = models.CharField(
        max_length=20,
        choices=FreePeriod.choices,
        default=FreePeriod.DAILY,
    )

    free_enquiry_limit = models.PositiveIntegerField(default=5)
    free_enquiry_period = models.CharField(
        max_length=20,
        choices=FreePeriod.choices,
        default=FreePeriod.DAILY,
    )

    block_contact_info = models.BooleanField(default=True)
    block_phone_numbers = models.BooleanField(default=True)
    block_emails = models.BooleanField(default=True)
    block_social_handles = models.BooleanField(default=True)
    block_external_links = models.BooleanField(default=True)

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
        verbose_name = "Bazaar Communication Settings"
        verbose_name_plural = "Bazaar Communication Settings"

    def __str__(self):
        return (
            f"Communication Settings "
            f"(chat={self.chat_mode}, enquiry={self.enquiry_mode})"
        )




##############################################################################
##############################################################################
#                            QNX CHAT MODEL
##############################################################################
##############################################################################


class BazaarChat(models.Model):
    user_one = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="bazaar_chats_as_user_one",
    )

    user_two = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="bazaar_chats_as_user_two",
    )

    listing = models.ForeignKey(
        "olx.BazaarListing",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="bazaar_chats",
    )

    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
        indexes = [
            models.Index(fields=["user_one", "is_active"]),
            models.Index(fields=["user_two", "is_active"]),
            models.Index(fields=["listing"]),
            models.Index(fields=["-updated_at"]),
        ]
        constraints = [
            models.CheckConstraint(
                condition=~Q(user_one=models.F("user_two")),
                name="bazaar_chat_different_users",
            ),
        ]

    def __str__(self):
        return f"Chat {self.pk}: {self.user_one_id} - {self.user_two_id}"

    def has_participant(self, user):
        return user.pk in (self.user_one_id, self.user_two_id)

    def get_other_participant(self, user):
        if user.pk == self.user_one_id:
            return self.user_two
        if user.pk == self.user_two_id:
            return self.user_one
        return None


class BazaarChatMessage(models.Model):
    class ModerationStatus(models.TextChoices):
        ALLOWED = "allowed", "Allowed"
        BLOCKED = "blocked", "Blocked"

    chat = models.ForeignKey(
        BazaarChat,
        on_delete=models.CASCADE,
        related_name="messages",
    )

    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="bazaar_chat_messages",
    )

    message = models.TextField()

    moderation_status = models.CharField(
        max_length=10,
        choices=ModerationStatus.choices,
        default=ModerationStatus.ALLOWED,
    )

    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["chat", "created_at"]),
            models.Index(fields=["sender", "created_at"]),
            models.Index(fields=["chat", "is_read"]),
            models.Index(fields=["moderation_status"]),
        ]
        constraints = [
            models.CheckConstraint(
                condition=~Q(message=""),
                name="bazaar_chat_message_not_empty",
            ),
        ]

    def __str__(self):
        return f"Message {self.pk} in Chat {self.chat_id}"