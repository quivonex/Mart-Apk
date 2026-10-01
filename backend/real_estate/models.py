from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.contrib.auth import get_user_model
from django.utils.text import slugify
from enquiry.models import MarketingPartner

User = get_user_model()

class Amenity(models.Model):
    name = models.CharField(max_length=100, unique=True)
    icon = models.CharField(max_length=100, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        db_table = "amenities"
        ordering = ["name"]
    def __str__(self):
        return self.name

class Builder(models.Model):
    name = models.CharField(max_length=255, unique=True)
    short_info = models.TextField(blank=True, null=True)
    logo_s3_key = models.CharField(max_length=255, blank=True, null=True)
    website = models.URLField(blank=True, null=True)
    email = models.EmailField(blank=True, null=True)
    phone = models.CharField(max_length=20, blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    class Meta:
        db_table = "builders"
        ordering = ["name"]
    def __str__(self):
        return self.name

class Property(models.Model):
    class PropertyType(models.TextChoices):
        FLAT = "flat", "Flat / Apartment"
        VILLA = "villa", "Villa / Bungalow"
        PLOT = "plot", "Plot / Land"
        COMMERCIAL = "commercial", "Commercial Space"
        SHOP = "shop", "Shop / Retail"
        OFFICE = "office", "Office Space"
        WAREHOUSE = "warehouse", "Warehouse"
        OTHER = "other", "Other"
    class TransactionType(models.TextChoices):
        
        SALE = "sale", "For Sale"
        RENT = "rent", "For Rent"
        LEASE = "lease", "For Lease"
        PG = "pg", "PG / Hostel"
        
    class PropertyCondition(models.TextChoices):
        NEW = "new", "New Property"
        RESALE = "resale", "Old / Resale Property"
    
            
    class ListingStatus(models.TextChoices):
        DRAFT = "draft", "Draft"
        PENDING = "pending", "Pending Approval"
        ACTIVE = "active", "Active"
        SOLD = "sold", "Sold"
        RENTED = "rented", "Rented"
        INACTIVE = "inactive", "Inactive"
        EXPIRED = "expired", "Expired"
    title = models.CharField(max_length=255)
    slug = models.SlugField(max_length=255, unique=True, blank=True)
    description = models.TextField()
    property_type = models.CharField(max_length=20, choices=PropertyType.choices, default=PropertyType.FLAT)
    transaction_type = models.CharField(max_length=10, choices=TransactionType.choices, default=TransactionType.SALE)
    property_condition = models.CharField(max_length=20,choices=PropertyCondition.choices,default=PropertyCondition.NEW)
    status = models.CharField(max_length=20, choices=ListingStatus.choices, default=ListingStatus.DRAFT)
    city = models.CharField(max_length=100)
    area = models.CharField(max_length=100)
    address = models.TextField()
    landmark = models.CharField(max_length=255, blank=True)
    pincode = models.CharField(max_length=10)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, blank=True, null=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, blank=True, null=True)
    google_location_url = models.URLField(blank=True, null=True)
    total_area = models.DecimalField(max_digits=12, decimal_places=2, validators=[MinValueValidator(0)],null=True, blank=True)
    plot_area = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True, validators=[MinValueValidator(0)])
    total_floors = models.PositiveIntegerField(default=1)
    total_towers = models.PositiveIntegerField(default=1)
    builder = models.ForeignKey(Builder, on_delete=models.SET_NULL, null=True, blank=True, related_name="properties")
    agent = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="properties")
    marketing_partner = models.ForeignKey(MarketingPartner, on_delete=models.SET_NULL, null=True, blank=True, related_name="properties")
    amenities = models.ManyToManyField(Amenity, blank=True, related_name="properties")
    rera_number = models.CharField(max_length=100, blank=True, null=True)
    rera_qr_code = models.URLField(max_length=500, blank=True, null=True)
    rera_website = models.URLField(blank=True, null=True)
    rera_additional_urls = models.JSONField(default=list, blank=True)
    property_website_url = models.URLField(blank=True, null=True)
    is_under_construction = models.BooleanField(default=False)
    ready_to_move = models.BooleanField(default=False)
    possession_date = models.DateField(blank=True, null=True)
    completion_percentage = models.PositiveIntegerField(default=0, validators=[MinValueValidator(0), MaxValueValidator(100)])
    features = models.JSONField(default=dict, blank=True)
    views_count = models.PositiveIntegerField(default=0)
    enquiry_count = models.PositiveIntegerField(default=0)
    favorite_count = models.PositiveIntegerField(default=0)
    status_approved = models.BooleanField(default=False)
    is_featured = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    is_negotiable = models.BooleanField(default=True)
    referral_code = models.CharField(max_length=50, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    published_at = models.DateTimeField(blank=True, null=True)
    expiry_date = models.DateTimeField(blank=True, null=True)
    source = models.CharField(max_length=20,choices=[("website", "Website"),("admin", "Admin Panel"),],default="website")
    free_days = models.PositiveIntegerField(default=15,null=True, blank=True)
    free_expiry_date = models.DateTimeField(blank=True,null=True)
    subscription_required = models.BooleanField(default=False)
    subscription_active = models.BooleanField(default=False)
    class Meta:
        db_table = "properties"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "transaction_type"]),
            models.Index(fields=["city", "area"]),
            models.Index(fields=["property_type"]),
            models.Index(fields=["builder"]),
            models.Index(fields=["rera_number"]),
        ]
    def __str__(self):
        return f"{self.title} - {self.city}"
    def save(self, *args, **kwargs):
        if not self.slug:
            base_slug = slugify(self.title)
            slug = base_slug
            counter = 1
            while Property.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)

class FlatType(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="flat_types")
    flat_type = models.CharField(max_length=50)
    area_sqft = models.DecimalField(max_digits=12, decimal_places=2,blank=True, null=True)
    carpet_area = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    built_up_area = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    balcony_area = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    bedrooms = models.PositiveIntegerField(default=0)
    bathrooms = models.PositiveIntegerField(default=0)
    balconies = models.PositiveIntegerField(default=0)
    kitchens = models.PositiveIntegerField(default=1)
    parking_count = models.PositiveIntegerField(default=0)
    description = models.TextField(blank=True)
    is_available = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    class Meta:
        db_table = "flat_types"
        # constraints = [
        #     models.UniqueConstraint(fields=["property", "flat_type"], name="unique_property_flat_type")
        # ]
        # ordering = ["flat_type"]
    def __str__(self):
        return f"{self.flat_type} - {self.area_sqft} sq.ft."

class FloorInfo(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="floors")
    floor_number = models.PositiveIntegerField()
    floor_name = models.CharField(max_length=100, blank=True)
    total_units = models.PositiveIntegerField(default=0)
    available_units = models.PositiveIntegerField(default=0)
    expected_completion_date = models.DateField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    class Meta:
        db_table = "floor_infos"
        constraints = [
            models.UniqueConstraint(fields=["property", "floor_number"], name="unique_property_floor")
        ]
        ordering = ["floor_number"]
    def __str__(self):
        return f"{self.property.title} - Floor {self.floor_number}"

class PricingSlab(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="pricing_slabs")
    floor = models.ForeignKey(FloorInfo, on_delete=models.CASCADE, related_name="pricing_slabs")
    flat_type = models.ForeignKey(FlatType, on_delete=models.CASCADE, related_name="pricing_slabs")
    base_price = models.DecimalField(max_digits=15, decimal_places=2, validators=[MinValueValidator(0)])
    price_per_sqft = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    booking_amount = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    discount_percentage = models.DecimalField(max_digits=5, decimal_places=2, default=0, validators=[MinValueValidator(0), MaxValueValidator(100)])
    gst_percentage = models.DecimalField(max_digits=5, decimal_places=2, default=5, validators=[MinValueValidator(0), MaxValueValidator(100)])
    payment_schedule = models.JSONField(default=dict, blank=True)
    additional_charges = models.JSONField(default=dict, blank=True)
    is_available = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    class Meta:
        db_table = "pricing_slabs"
        constraints = [
            models.UniqueConstraint(fields=["property", "floor", "flat_type"], name="unique_property_floor_flat")
        ]
        ordering = ["floor__floor_number", "flat_type__flat_type"]
    def __str__(self):
        return f"{self.property.title} - Floor {self.floor.floor_number} - {self.flat_type.flat_type}"
    def get_discount_amount(self):
        return self.base_price * self.discount_percentage / 100
    def get_price_after_discount(self):
        return self.base_price - self.get_discount_amount()
    def get_gst_amount(self):
        return self.get_price_after_discount() * self.gst_percentage / 100
    def get_final_price(self):
        return self.get_price_after_discount() + self.get_gst_amount()


class PropertyImage(models.Model):
    class ImageType(models.TextChoices):
        EXTERIOR = "exterior", "Exterior"
        INTERIOR = "interior", "Interior"
        FLOOR_PLAN = "floor_plan", "Floor Plan"
        LAYOUT = "layout", "Layout"
        KITCHEN = "kitchen", "Kitchen"
        BEDROOM = "bedroom", "Bedroom"
        BATHROOM = "bathroom", "Bathroom"
        AMENITY = "amenity", "Amenity"
        PLOT = "plot", "Plot"
        OTHER = "other", "Other"
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="images")
    image_s3_key = models.URLField(max_length=1000)
    image_type = models.CharField(max_length=30, choices=ImageType.choices, default=ImageType.OTHER)
    caption = models.CharField(max_length=255, blank=True)
    parameters = models.JSONField(default=dict, blank=True)
    is_primary = models.BooleanField(default=False)
    display_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        db_table = "property_images"
        ordering = ["display_order", "created_at"]
    def __str__(self):
        return f"Image - {self.property.title}"
    def save(self, *args, **kwargs):
        if self.is_primary:
            PropertyImage.objects.filter(property=self.property, is_primary=True).exclude(pk=self.pk).update(is_primary=False)
        super().save(*args, **kwargs)

class PropertyVideo(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="videos")
    video_s3_key = models.URLField(max_length=1000)
    title = models.CharField(max_length=255, blank=True)
    thumbnail_url = models.URLField(max_length=500, blank=True, null=True)
    is_featured = models.BooleanField(default=False)
    display_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        db_table = "property_videos"
        ordering = ["display_order", "created_at"]
    def __str__(self):
        return f"Video - {self.property.title}"

class PropertyDocument(models.Model):
    class DocumentType(models.TextChoices):
        SALE_DEED = "sale_deed", "Sale Deed"
        AGREEMENT = "agreement", "Agreement"
        NOC = "noc", "NOC"
        APPROVAL = "approval", "Approval"
        REGISTRATION = "registration", "Registration"
        RERA = "rera", "RERA Document"
        OTHER = "other", "Other"
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="documents")
    document_type = models.CharField(max_length=30, choices=DocumentType.choices, default=DocumentType.OTHER)
    title = models.CharField(max_length=255)
    file_url = models.URLField(max_length=1000)
    description = models.TextField(blank=True)
    is_verified = models.BooleanField(default=False)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        db_table = "property_documents"
        ordering = ["-uploaded_at"]
    def __str__(self):
        return f"{self.title} - {self.property.title}"
    
class PropertySubscriptionSetting(models.Model):
    free_days = models.PositiveIntegerField(default=15)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "property_subscription_settings"

    
class ChatbotLead(models.Model):

    name = models.CharField(
        max_length=255,
        null=True,
        blank=True
    )

    mobile = models.CharField(
        max_length=20,
        null=True,
        blank=True
    )

    email = models.EmailField(
        null=True,
        blank=True
    )

    purpose = models.CharField(
        max_length=20,
        null=True,
        blank=True
    )

    property_type = models.CharField(
        max_length=50,
        null=True,
        blank=True
    )

    city = models.CharField(
        max_length=100,
        null=True,
        blank=True
    )

    location = models.CharField(
        max_length=255,
        null=True,
        blank=True
    )

    bhk = models.IntegerField(
        null=True,
        blank=True
    )

    min_budget = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True
    )

    max_budget = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return self.name or "Chatbot Lead"
    
    
from django.db import models


class ChatSession(models.Model):

    session_id = models.CharField(
        max_length=100,
        unique=True
    )

    purpose = models.CharField(
        max_length=20,
        null=True,
        blank=True
    )

    property_type = models.CharField(
        max_length=50,
        null=True,
        blank=True
    )

    city = models.CharField(
        max_length=100,
        null=True,
        blank=True
    )

    location = models.CharField(
        max_length=255,
        null=True,
        blank=True
    )

    bhk = models.IntegerField(
        null=True,
        blank=True
    )

    min_budget = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True
    )

    max_budget = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True
    )

    current_step = models.CharField(
        max_length=50,
        default="purpose"
    )

    is_completed = models.BooleanField(
        default=False
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return self.session_id


class ChatMessage(models.Model):

    session = models.ForeignKey(
        ChatSession,
        on_delete=models.CASCADE,
        related_name="messages"
    )

    sender = models.CharField(
        max_length=10,
        choices=[
            ("user", "User"),
            ("bot", "Bot"),
        ]
    )

    message = models.TextField()

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return f"{self.sender} - {self.message[:30]}"    
    
    
    from django.db import models
from django.conf import settings


class RealEstateChannelPartner(models.Model):

    STATUS_CHOICES = (
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('pending', 'Pending'),
    )
     # Login/User
    user = models.OneToOneField(
            settings.AUTH_USER_MODEL,
            on_delete=models.SET_NULL,
            null=True,
            blank=True,
            related_name='real_estate_channel_partner'
        )
    # Basic Details
    name = models.CharField(max_length=150)
    company_name = models.CharField(max_length=200, blank=True, null=True)

    # Contact Details
    mobile = models.CharField(max_length=15, unique=True)
    email = models.EmailField(blank=True, null=True)

    # Address
    address = models.TextField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    state = models.CharField(max_length=100, blank=True, null=True)
    pincode = models.CharField(max_length=10, blank=True, null=True)

    # CP Information
    cp_code = models.CharField(max_length=50, unique=True)
    rera_number = models.CharField(max_length=100, blank=True, null=True)

    # Commission
    commission_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0
    )

    # Status
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )

   

    # Extra
    notes = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.cp_code} - {self.name}"
    
    
    
class RealEstatePropertyCommission(models.Model):

    property = models.ForeignKey(
        Property,
        on_delete=models.CASCADE,
        related_name='commissions'
    )

    channel_partner = models.ForeignKey(
        RealEstateChannelPartner,
        on_delete=models.CASCADE,
        related_name='property_commissions'
    )

    sale_price = models.DecimalField(
        max_digits=15,
        decimal_places=2
    )

    cp_commission_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2
    )

    cp_commission_amount = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=0
    )

    business_partner_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0
    )

    business_partner_amount = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=0
    )

    cp_final_amount = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=0
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['property', 'channel_partner'],
                name='unique_property_channel_partner'
            )
        ]

    def __str__(self):
        return (
            f"{self.property} - "
            f"{self.channel_partner.cp_code} - "
            f"{self.sale_price}"
        )
        
        
        
class RealEstateCommissionTransaction(models.Model):

    TRANSACTION_TYPE_CHOICES = (
        (
            'BUSINESS_PARTNER_COMMISSION',
            'Business Partner Commission'
        ),
    )

    PAYMENT_METHOD_CHOICES = (
        ('UPI', 'UPI'),
        ('BANK_TRANSFER', 'Bank Transfer'),
        ('NEFT', 'NEFT'),
        ('RTGS', 'RTGS'),
        ('IMPS', 'IMPS'),
        ('CHEQUE', 'Cheque'),
        ('CASH', 'Cash'),
    )

    GATEWAY_CHOICES = (
        ('RAZORPAY', 'Razorpay'),
        ('MANUAL', 'Manual'),
    )

    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('PROCESSING', 'Processing'),
        ('SUCCESS', 'Success'),
        ('FAILED', 'Failed'),
        ('REVERSED', 'Reversed'),
    )

    commission = models.ForeignKey(
        RealEstatePropertyCommission,
        on_delete=models.CASCADE,
        related_name='transactions'
    )

    transaction_type = models.CharField(
        max_length=50,
        choices=TRANSACTION_TYPE_CHOICES,
        default='BUSINESS_PARTNER_COMMISSION'
    )

    amount = models.DecimalField(
        max_digits=15,
        decimal_places=2
    )

    payment_method = models.CharField(
        max_length=30,
        choices=PAYMENT_METHOD_CHOICES
    )

    gateway = models.CharField(
        max_length=20,
        choices=GATEWAY_CHOICES
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='PENDING'
    )

    razorpay_payout_id = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    utr = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    reference_id = models.CharField(
        max_length=100,
        unique=True
    )

    remarks = models.TextField(
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )        
from enquiry.models import MarketingPartner    
class PropertyEnquiry(models.Model):

    class Status(models.TextChoices):
        NEW = "new", "New"
        CONTACTED = "contacted", "Contacted"
        SITE_VISIT = "site_visit", "Site Visit"
        NEGOTIATION = "negotiation", "Negotiation"
        BOOKED = "booked", "Booked"
        CLOSED = "closed", "Closed"
    class FlatType(models.TextChoices):
        STUDIO = "studio", "Studio"
        ONE_BHK = "1_bhk", "1 BHK"
        TWO_BHK = "2_bhk", "2 BHK"
        THREE_BHK = "3_bhk", "3 BHK"
        FOUR_BHK = "4_bhk", "4 BHK"
        FIVE_BHK = "5_bhk", "5 BHK"
        OTHER = "other", "Other"
        
    class MeetingStatus(models.TextChoices):
        SCHEDULED = "scheduled", "Scheduled"
        CONFIRMED = "confirmed", "Confirmed"
        RESCHEDULED = "rescheduled", "Rescheduled"
        COMPLETED = "completed", "Completed"
        CUSTOMER_NOT_ATTENDED = "customer_not_attended", "Customer Not Attended"
        PARTNER_NOT_ATTENDED = "partner_not_attended", "Partner Not Attended"
        CANCELLED = "cancelled", "Cancelled"   
    property = models.ForeignKey(Property,on_delete=models.CASCADE,related_name="enquiries")
    customer_name = models.CharField(max_length=100)
    customer_email = models.EmailField(blank=True,null=True)
    customer_mobile = models.CharField(max_length=15)
    flat_type = models.CharField(max_length=20,choices=FlatType.choices,blank=True,null=True)
    budget_min = models.DecimalField(max_digits=15,decimal_places=2,blank=True,null=True)
    budget_max = models.DecimalField(max_digits=15,decimal_places=2,blank=True,null=True)
    message = models.TextField(blank=True,null=True)
    status = models.CharField(max_length=20,choices=Status.choices,default=Status.NEW)
    assigned_channel_partner = models.ForeignKey(MarketingPartner,on_delete=models.SET_NULL,null=True,blank=True,related_name="assigned_enquiries")
    assigned_at = models.DateTimeField(null=True, blank=True)
    followup_date = models.DateField(null=True,blank=True)
    meeting_date = models.DateField(null=True,blank=True)
    meeting_time = models.TimeField(null=True,blank=True)
    meeting_location = models.CharField(max_length=255,blank=True,null=True)
    meeting_notes = models.TextField(blank=True,null=True)
    meeting_scheduled_at = models.DateTimeField(null=True,blank=True)
    whatsapp_sent = models.BooleanField(default=False)
    whatsapp_sent_at = models.DateTimeField(null=True,blank=True)
    whatsapp_response = models.JSONField(null=True,blank=True)
    
    meeting_status = models.CharField(max_length=30,choices=MeetingStatus.choices,default=MeetingStatus.SCHEDULED)
    meeting_outcome = models.TextField(blank=True,null=True)
    meeting_feedback = models.TextField(blank=True,null=True)
    next_followup_date = models.DateField(blank=True,null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.customer_name    
    
