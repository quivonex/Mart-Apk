from django.db import models
from accounts.models import User # type: ignore


class Company(models.Model):
    # Basic info
    user = models.ForeignKey(User,on_delete=models.CASCADE,null=True,blank=True,related_name="companies")
    name = models.CharField(max_length=200,unique=True)
    owner_name = models.CharField(max_length=200, blank=True, null=True)
    email = models.EmailField(unique=True, blank=True, null=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    gst_number = models.CharField(max_length=50, blank=True, null=True, unique=True)
    logo_s3_key = models.CharField(max_length=255, blank=True, null=True)
    # is_franchise_available = models.BooleanField(default=False)
    accept_terms_conditions = models.BooleanField(default=False)
    state = models.CharField(max_length=100, blank=True, null=True)
    district = models.CharField(max_length=100, blank=True, null=True)
    taluka = models.CharField(max_length=100, blank=True, null=True)
    village = models.CharField(max_length=100, blank=True, null=True)
    pincode = models.CharField(max_length=10, blank=True, null=True)
    short_description = models.CharField(max_length=160, blank=True, null=True)
    long_description = models.TextField(blank=True, null=True)
    pickup_location = models.CharField(max_length=100,blank=True,null=True)
    company_slogan = models.CharField(max_length=255, blank=True, null=True)
    farm_registration_year = models.PositiveIntegerField(blank=True, null=True)
    registration_no = models.CharField(max_length=100, blank=True, null=True, unique=True)
    company_pan_no = models.CharField(max_length=20, blank=True, null=True, unique=True)
    multiple_email_ids = models.JSONField(blank=True, null=True)  # List of emails
    contacts = models.JSONField(blank=True, null=True)  # List of contact numbers
    whatsapp_no = models.CharField(max_length=10, blank=True, null=True)
    website_url = models.URLField(blank=True, null=True)
    facebook_url = models.URLField(blank=True, null=True)
    linkedin_url = models.URLField(blank=True, null=True)
    instagram_url = models.URLField(blank=True, null=True)
    youtube_url = models.URLField(blank=True, null=True)
    privacy_policy_url = models.URLField(blank=True, null=True)
    terms_conditions_url = models.URLField(blank=True, null=True)
    social_media_accounts = models.JSONField(blank=True, null=True)  # e.g. {"facebook": "url", "instagram": "url"}
    IAN_No = models.CharField(max_length=25, blank=True, null=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    location_address = models.TextField(blank=True, null=True)
    # Status
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    referral_code = models.CharField(max_length=50, blank=True, null=True)
    # referral_link = models.URLField(blank=True, null=True)
    marketing_partner_name = models.CharField(max_length=200, blank=True, null=True)
    payment_id = models.CharField(max_length=200, blank=True, null=True)
    order_id = models.CharField(max_length=200, blank=True, null=True)
    payment_status = models.CharField(max_length=20, default="pending")
    ISI_certified = models.BooleanField(default=False)
    ISO_certified = models.BooleanField(default=False)
    COD_available = models.BooleanField(default=False)
    def __str__(self):
        return self.name
    is_agreement_approved = models.BooleanField(default=False)

class CompanyImage(models.Model):

    company = models.ForeignKey(Company,on_delete=models.CASCADE,related_name="images")
    image_s3_key = models.CharField(max_length=255)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.company.name} Image"        
    
    
class CompanyPayment(models.Model):
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="payments")
    order_id = models.CharField(max_length=200)
    payment_id = models.CharField(max_length=200, null=True, blank=True)
    signature = models.CharField(max_length=255, null=True, blank=True)
    amount = models.IntegerField()
    currency = models.CharField(max_length=10, default="INR")
    status = models.CharField(
        max_length=20,
        default="pending"
    )
    # pending | paid | failed

    created_at = models.DateTimeField(auto_now_add=True)    
    
    
class suppliers(models.Model):
    name = models.CharField(max_length=200)
    email = models.EmailField()
    phone = models.CharField(max_length=20)
    address = models.TextField()
    state = models.CharField(max_length=100)
    district = models.CharField(max_length=100)
    taluka = models.CharField(max_length=100)
    village = models.CharField(max_length=100)
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="suppliers")
    created_at = models.DateTimeField(auto_now_add=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)

    def __str__(self):
        return self.name