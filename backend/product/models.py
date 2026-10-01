import re

from django.db import models   # type: ignore
import random
import string
from accounts.models import User # type: ignore
from datetime import date

from offer.models import Offer # type: ignore

from django.db.models import Q
from decimal import Decimal
from django.utils.text import slugify


class Category(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE,null=True, blank=True, related_name="categories")
    branch = models.ForeignKey('branch.Branch', on_delete=models.CASCADE,null=True, blank=True, related_name="categories")
    company = models.ForeignKey('company.Company', on_delete=models.CASCADE,null=True, blank=True, related_name="categories")
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name



class SubCategory(models.Model):
    user = models.ForeignKey(User,on_delete=models.CASCADE,null=True,blank=True,related_name="subcategories")
    category = models.ForeignKey(Category,on_delete=models.CASCADE,related_name="subcategories")
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.category.name} - {self.name}"        


class Brand(models.Model):
    user = models.ForeignKey(User,on_delete=models.CASCADE,null=True,blank=True,related_name="brands")
    category = models.ForeignKey(Category,on_delete=models.CASCADE,blank=True, null=True,related_name="brands")
    subcategory = models.ForeignKey(SubCategory,on_delete=models.SET_NULL,null=True,blank=True,related_name="brands")
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class Unit(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE,null=True, blank=True, related_name="units")
    name = models.CharField(max_length=50)      # Kg, Piece, Box, Liter
    short_name = models.CharField(max_length=20)  # kg, pc, box
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name



def generate_product_code():
    prefix = "PRD-"
    random_part = ''.join(random.choices(string.ascii_uppercase + string.digits, k=12))
    return prefix + random_part

class Product(models.Model):

    DISCOUNT_TYPE_CHOICES = (('flat', 'Flat'),('percent', 'Percentage'),)
    STATUS_CHOICES = (('pending', 'Pending'),('approved', 'Approved'),('rejected', 'Rejected'),)
    company = models.ForeignKey('company.Company', on_delete=models.CASCADE,null=True, blank=True, related_name="products")
    slug = models.SlugField(max_length=255, unique=True, blank=True, null=True) 
    category = models.ForeignKey(Category,on_delete=models.SET_NULL,null=True,related_name="products")
    subcategory = models.ForeignKey(SubCategory,on_delete=models.SET_NULL,null=True,blank=True,related_name="products")
    brand = models.ForeignKey(Brand,on_delete=models.SET_NULL,null=True,blank=True,related_name="products")
    branch = models.ForeignKey('branch.Branch', on_delete=models.CASCADE,null=True, blank=True, related_name="products")
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True, null=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    discount_type = models.CharField(max_length=10,choices=DISCOUNT_TYPE_CHOICES,blank=True,null=True)
    discount_value = models.DecimalField(max_digits=10,decimal_places=2,blank=True,null=True)
    final_price = models.DecimalField(max_digits=10,decimal_places=2,blank=True,null=True)
    unit = models.ForeignKey(Unit,on_delete=models.SET_NULL,null=True,blank=True)
    stock_quantity = models.IntegerField(default=0)
    weight = models.CharField(max_length=100, blank=True)
    length  = models.CharField(max_length=100, blank=True)
    width = models.CharField(max_length=100, blank=True)
    height = models.CharField(max_length=100, blank=True)
    product_code = models.CharField(max_length=100, blank=True, null=True)
    specifications = models.JSONField(blank=True, null=True)
    # variants = models.JSONField(blank=True, null=True)
    thumbnail_s3_key = models.CharField(max_length=255, blank=True, null=True)
    manufacturing_date = models.DateField(null=True, blank=True)
    expiry_date = models.DateField(null=True, blank=True)
    best_before_duration = models.CharField(max_length=50, blank=True)
    status = models.CharField(max_length=10,choices=STATUS_CHOICES,default='pending')
    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    HSN_code = models.CharField(max_length=20,null=True, blank=True)
    GST_percent = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    is_franchise_available = models.BooleanField(default=False)
    


    def save(self, *args, **kwargs):
        if not self.slug and self.name:
            base_slug = slugify(self.name)
            
            # First, try with just the base slug
            if not Product.objects.filter(slug=base_slug).exclude(pk=self.pk).exists():
                self.slug = base_slug
            else:
                # If base slug exists, append random 6-character code
                while True:
                    # Option 1: Random alphanumeric code (e.g., shirt-a7x9p2)
                    random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
                    unique_slug = f"{base_slug}-{random_suffix}"
                    
                    # Option 2: Or use counter (e.g., shirt-1, shirt-2)
                    # You can also use this approach instead:
                    # counter = 1
                    # while Product.objects.filter(slug=unique_slug).exclude(pk=self.pk).exists():
                    #     unique_slug = f"{base_slug}-{counter}"
                    #     counter += 1
                    
                    if not Product.objects.filter(slug=unique_slug).exclude(pk=self.pk).exists():
                        self.slug = unique_slug
                        break
            
        # ✅ Auto Product Code
        if not self.product_code:
            while True:
                code = generate_product_code()
                if not Product.objects.filter(product_code=code).exists():
                    self.product_code = code
                    break

        # ✅ Discount Calculation
        if self.discount_type == 'flat' and self.discount_value:
            self.final_price = self.price - self.discount_value

        elif self.discount_type == 'percent' and self.discount_value:
            discount_amount = (self.price * self.discount_value) / Decimal('100')
            self.final_price = self.price - discount_amount

        else:
            self.final_price = self.price

        super().save(*args, **kwargs)

#############🔥 OFFER LOGIC
    def get_final_price_with_offer(self):
        today = date.today()

        # 👉 Default = discounted price
        base_price = self.final_price or self.price

        offer = self.offers.filter(
            is_active=True
        ).filter(
            Q(start_date__lte=today) | Q(start_date__isnull=True),
            Q(end_date__gte=today) | Q(end_date__isnull=True)
        ).order_by('-id').first()

        # ✅ If NO offer → return discount price
        if not offer or not offer.discount_value:
            return base_price

        # ✅ Branch check
        if offer.branch.exists():
            if not self.branch or self.branch not in offer.branch.all():
                return base_price

        offer_type = (offer.offer_type or "").strip().lower()

        # ✅ Apply offer on ORIGINAL price (as per your requirement)
        original_price = self.price

        if offer_type == "percentage":
            discount = (original_price * offer.discount_value) / Decimal('100')
            return max(original_price - discount, Decimal('0'))

        elif offer_type == "flat":
            return max(original_price - offer.discount_value, Decimal('0'))

        return base_price
    
##############
    import re


def convert_weight_to_kg(weight):
    if not weight:
        return 0

    weight = str(weight).lower().strip()

    value = float(re.findall(r"[\d.]+", weight)[0])

    if "kg" in weight:
        return value

    if "g" in weight:
        return value / 1000

    return value


def convert_dimension_to_cm(value):
    if not value:
        return 0

    value = str(value).lower().strip()

    number = float(re.findall(r"[\d.]+", value)[0])

    if "mm" in value:
        return number / 10

    if "m" in value and "cm" not in value:
        return number * 100

    return number

def __str__(self):
        return self.name

class ProductImage(models.Model):
    product = models.ForeignKey(Product,on_delete=models.CASCADE,related_name="images")
    image_s3_key = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Image for {self.product.name}"


class ProductVideo(models.Model):

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="videos")

    video_s3_key = models.CharField(max_length=255)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Video for {self.product.name}"   



class ProductVariant(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="variants")
    attributes = models.JSONField()  # ["Red","M"] किंवा {"color": "Red"}
    price = models.DecimalField(max_digits=10, decimal_places=2)
    stock_quantity = models.IntegerField(default=0)
    sku = models.CharField(max_length=100, unique=True)
    image_index = models.IntegerField(default=0)  # optional: shows which main product image this variant belongs to
    image_s3_key = models.CharField(max_length=255, blank=True, null=True)  # <-- S3 URL for variant image

    def __str__(self):
        return f"{self.product.name} - {self.attributes}"
    
    # 🔥 OFFER LOGIC FOR VARIANTS
    def get_final_price_with_offer(self):
        product = self.product
        today = date.today()

        # ✅ Step 1: Product discount apply
        if product.discount_type == 'flat' and product.discount_value:
            discounted_price = self.price - product.discount_value

        elif product.discount_type == 'percent' and product.discount_value:
            discount_amount = (self.price * product.discount_value) / Decimal('100')
            discounted_price = self.price - discount_amount

        else:
            discounted_price = self.price

        # 🔍 Offer check
        offer = product.offers.filter(
            is_active=True
        ).filter(
            Q(start_date__lte=today) | Q(start_date__isnull=True),
            Q(end_date__gte=today) | Q(end_date__isnull=True)
        ).order_by('-id').first()

        # ❌ No offer → return discounted price
        if not offer or not offer.discount_value:
            return max(discounted_price, Decimal('0'))

        # ✅ Offer exists → ONLY offer apply (ignore discount)
        original_price = self.price
        offer_type = (offer.offer_type or "").strip().lower()

        if offer_type in ["percentage", "percent"]:
            discount = (original_price * offer.discount_value) / Decimal('100')
            return max(original_price - discount, Decimal('0'))

        elif offer_type == "flat":
            return max(original_price - offer.discount_value, Decimal('0'))

        return max(discounted_price, Decimal('0'))

# Search History Model(aditya)
# from django.db import models
# from django.contrib.auth.models import User

class ProductViewHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    viewed_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'product')  # duplicate entry avoid

    def __str__(self):
        return f"{self.user} viewed {self.product.name}"    
    

class SearchHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    search_text = models.CharField(max_length=255)
    searched_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user} searched {self.search_text}"


class ProductUpdateRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )

    product = models.ForeignKey('product.Product', on_delete=models.CASCADE, related_name="update_requests")
    requested_by = models.ForeignKey('accounts.User', on_delete=models.CASCADE)
    updated_data = models.JSONField()  # 🔥 full product data
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Update request for {self.product.name}"



