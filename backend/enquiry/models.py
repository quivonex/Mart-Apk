from django.db import models # type: ignore
from agreement.models import CompanyAgreement
from company.models import Company
from product.models import Product
import random
import string
from accounts.models import User

class Enquiry(models.Model):

    USER_TYPE = (
        ('personal', 'Personal'),
        ('business', 'Business'),
        ('organisation', 'Organisation'),
    )

    DEMO_REQUIRED = (
        ('yes', 'Yes'),
        ('no', 'No'),
    )

    DEMO_TYPE = (
        ('location', 'At Your Location'),
        ('online', 'Online'),
        ('center', 'At Center'),
    )

    person_name = models.CharField(max_length=200)
    user_type = models.CharField(max_length=20, choices=USER_TYPE)
    shop_name = models.CharField(max_length=200, blank=True, null=True)
    firm_name = models.CharField(max_length=200, blank=True, null=True)
    company_name = models.CharField(max_length=200, blank=True, null=True)
    contacts = models.JSONField(blank=True, null=True)
    emails = models.JSONField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    pincode = models.CharField(max_length=10)
    message = models.TextField(blank=True, null=True)
    attachment = models.FileField(upload_to="enquiry_files/", blank=True, null=True)
    demo_required = models.CharField(max_length=10, choices=DEMO_REQUIRED, default='no')
    demo_type = models.CharField(max_length=20, choices=DEMO_TYPE, blank=True, null=True)
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    products = models.ManyToManyField('product.Product', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.person_name
    





class Uenquiry(models.Model):

    name = models.CharField(max_length=150)
    email = models.EmailField()
    phone = models.CharField(max_length=15)
    product = models.CharField(max_length=200)
    address = models.TextField(blank=True, null=True)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.product}"




class ProductEnquiry(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    DEMO_REQUIRED_CHOICES = (
        ('yes', 'Yes'),
        ('no', 'No'),
    )

    DEMO_TYPE_CHOICES = (
        ('at_location', 'At Location'),
        ('online', 'Online'),
    )

    # 🔹 Product Reference
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="product_enquiries")
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="enquiries")

    # 🔹 Selected Variants
    selected_color = models.CharField(max_length=50, blank=True, null=True)
    selected_size = models.CharField(max_length=50, blank=True, null=True)
    selected_variant = models.CharField(max_length=100, blank=True, null=True)
    quantity = models.PositiveIntegerField(default=1)

    # 🔹 User Details
    person_name = models.CharField(max_length=200)
    email = models.EmailField()
    contact = models.CharField(max_length=15)
    pincode = models.CharField(max_length=10)
    address = models.TextField()
    
    # 🔹 Message
    message = models.TextField()

    # 🔹 Demo
    demo_required = models.CharField(max_length=10, choices=DEMO_REQUIRED_CHOICES, default='no')
    demo_type = models.CharField(max_length=20, choices=DEMO_TYPE_CHOICES, blank=True, null=True)
    attachment = models.FileField(upload_to="enquiry_attachments/", blank=True, null=True)
    # 🔹 Status (Admin side)
    is_sent_to_company = models.BooleanField(default=False)
    is_complete = models.BooleanField(default=False,  blank=True, null=True)  # 
    is_dispatched = models.BooleanField(default=False) 
    is_delivered = models.BooleanField(default=False)  # 🔥 If all required fields are filled
    unit_price = models.DecimalField(max_digits=10,decimal_places=2,null=True,blank=True)
    total_amount = models.DecimalField(max_digits=12,decimal_places=2,null=True,blank=True)
    status = models.CharField(max_length=20,choices=STATUS_CHOICES,default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    is_paid = models.BooleanField(default=False)
    razorpay_payment_id = models.CharField(max_length=200, blank=True, null=True)
    enquiry_referral_code = models.CharField(max_length=20, blank=True, null=True)
   

    def __str__(self):
        return f"{self.person_name} - {self.product.name}"        




from django.db import models
from product.models import Product
from accounts.models import User

import random
import string
from django.db import models
from accounts.models import User

import random
import string


class MarketingPartner(models.Model):

    # 🔹 LOGIN USER RELATION
    user = models.OneToOneField(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="marketing_partner_profile"
    )

    APPLICATION_TYPE_CHOICES = (
        ('marketing_head', 'Marketing Head'),
        ('marketing_partner', 'Marketing Partner'),
    )

    application_type = models.CharField(
        max_length=30,
        choices=APPLICATION_TYPE_CHOICES,
        default='marketing_partner'
    )

    # 🔹 REFERRAL RELATION
    referred_by = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='referred_partners'
    )

    # 🔹 OTP VERIFIED
    otp_verified = models.BooleanField(default=False)

    # 🔹 STEP 1: Personal Info
    full_name = models.CharField(max_length=200)

    email = models.EmailField()
    
    mobile = models.CharField(max_length=15)

    profile_image = models.URLField(
        null=True,
        blank=True
    )

    state = models.CharField(max_length=100, blank=True, null=True)

    district = models.CharField(max_length=100, blank=True, null=True)

    taluka = models.CharField(max_length=100, blank=True, null=True)

    village = models.CharField(max_length=100, blank=True, null=True)

    pincode = models.CharField(max_length=10, blank=True, null=True)
    
    working_area = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    profession = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    experience = models.TextField(
        null=True,
        blank=True
    )

    PROMOTION_PLATFORM_CHOICES = (
        ('instagram', 'Instagram'),
        ('facebook', 'Facebook'),
        ('youtube', 'YouTube'),
        ('whatsapp', 'WhatsApp'),
        ('offline', 'Offline Marketing'),
        ('other', 'Other'),
    )

    # 🔹 MULTIPLE PLATFORMS
    promotion_platforms = models.JSONField(
        default=list,
        blank=True,
        null=True
    )

    team_size = models.PositiveIntegerField(default=1)

    # 🔹 Status Tracking
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )

    # 🔹 Referral
    referral_code = models.CharField(
        max_length=20,
        unique=True,
        blank=True,
        null=True
    )

    referral_link = models.URLField(
        blank=True,
        null=True
    )
    
    # 🔹 Meta
    created_at = models.DateTimeField(
        auto_now_add=True
    )
   

    def generate_referral_code(self):

        return 'MP' + ''.join(
            random.choices(
                string.ascii_uppercase + string.digits,
                k=8
            )
        )

    def save(self, *args, **kwargs):

        # 🔹 Generate unique referral code
        if not self.referral_code:

            code = self.generate_referral_code()

            while MarketingPartner.objects.filter(
                referral_code=code
            ).exists():

                code = self.generate_referral_code()

            self.referral_code = code

        super().save(*args, **kwargs)

    def __str__(self):
        return self.full_name
    
    
class BankDetails(models.Model):
    ACCOUNT_TYPE_CHOICES = [
        ('savings', 'Savings'),
        ('current', 'Current'),
    ]

    marketing_partner = models.OneToOneField(
        MarketingPartner,
        on_delete=models.CASCADE,
        related_name="bank_details"
    )

    # 🔹 Bank Details
    account_holder_name = models.CharField(max_length=200)
    bank_name = models.CharField(max_length=200)
    branch_name = models.CharField(max_length=200, blank=True, null=True)

    account_number = models.CharField(max_length=30)
    ifsc_code = models.CharField(max_length=20)

    account_type = models.CharField(
        max_length=20,
        choices=ACCOUNT_TYPE_CHOICES,
        default='savings'
    )

    # 🔹 UPI Details
    upi_id = models.CharField(max_length=100, blank=True, null=True)


    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.account_holder_name} - {self.bank_name}"    
    
    
    