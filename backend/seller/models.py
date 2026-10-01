from django.db import models

class Seller(models.Model):

    # 🔹 STEP 1: Business Information
    BUSINESS_TYPE_CHOICES = [
        ('individual', 'Individual / Proprietorship'),
        ('partnership', 'Partnership'),
        ('llp', 'LLP'),
        ('private_limited', 'Private Limited'),
        ('public_limited', 'Public Limited'),
    ]

    BUSINESS_CATEGORY_CHOICES = [
        ('electronics', 'Electronics'),
        ('fashion', 'Fashion'),
        ('home', 'Home & Kitchen'),
        ('books', 'Books'),
        ('sports', 'Sports'),
        ('automotive', 'Automotive'),
        ('grocery', 'Grocery'),
        ('health', 'Health'),
        ('toys', 'Toys'),
        ('other', 'Other'),
    ]
    user = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='sellers')  # ✅ Link to User
    business_type = models.CharField(max_length=50, choices=BUSINESS_TYPE_CHOICES)
    business_category = models.CharField(max_length=50, choices=BUSINESS_CATEGORY_CHOICES)
    # 🔹 STEP 2: Contact Details
    contact_person_name = models.CharField(max_length=200)
    designation = models.CharField(max_length=100)

    email = models.EmailField()
    mobile = models.CharField(max_length=15)
    alternate_mobile = models.CharField(max_length=15, blank=True, null=True)
    landline = models.CharField(max_length=20, blank=True, null=True)

    address = models.TextField()

    STATE_CHOICES = [
        ('MH', 'Maharashtra'),
        ('DL', 'Delhi'),
        ('KA', 'Karnataka'),
        ('TN', 'Tamil Nadu'),
        # तू बाकी add करू शकतोस
    ]

    state = models.CharField(max_length=10, choices=STATE_CHOICES)
    city = models.CharField(max_length=100)
    pincode = models.CharField(max_length=6)
    
    # 🔹 STEP 3: Bank & Tax (future use)
    bank_name = models.CharField(max_length=150, blank=True, null=True)
    account_number = models.CharField(max_length=50, blank=True, null=True)
    ifsc_code = models.CharField(max_length=20, blank=True, null=True)
    # gst_number = models.CharField(max_length=20, blank=True, null=True)
    # pan_number = models.CharField(max_length=20)

    # # 🔹 STEP 4: Documents
    # gst_certificate = models.FileField(upload_to='seller_docs/', blank=True, null=True)
    # pan_card = models.FileField(upload_to='seller_docs/', blank=True, null=True)

    # 🔹 Extra
    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.contact_person_name