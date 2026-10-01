from django.db import models
from django.conf import settings
from django.utils import timezone


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