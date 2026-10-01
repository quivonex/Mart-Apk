from django.db import models

from accounts.models import User
from product.models import Product
from company.models import Company  

class FranchisePlan(models.Model):
    user = models.ForeignKey(User,on_delete=models.CASCADE,null=True,blank=True,related_name="franchise_plans")
    company = models.ForeignKey(Company,on_delete=models.CASCADE,related_name='franchise_plans')
    product = models.ForeignKey(Product,on_delete=models.CASCADE,related_name='franchise_plans')
    plan_name = models.CharField(max_length=100)  # Silver, Gold, Platinum
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.company.name} - ₹{self.amount}"

class Franchise(models.Model):
    STATUS_CHOICES = (
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('pending', 'Pending'),
    )
    company = models.ForeignKey('company.Company', on_delete=models.CASCADE, related_name='franchises')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='franchises')
    FranchisePlan = models.ForeignKey(FranchisePlan, on_delete=models.CASCADE, related_name='franchises')
    # franchise_code = models.CharField(max_length=20, unique=True)
    franchise_name = models.CharField(max_length=200)
    owner_name = models.CharField(max_length=200)
    email = models.EmailField(unique=True)
    mobile_no = models.CharField(max_length=15)
    alternate_mobile_no = models.CharField(max_length=15, blank=True, null=True)

    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10)

    gst_no = models.CharField(max_length=20, blank=True, null=True)
    pan_no = models.CharField(max_length=20, blank=True, null=True)


    joining_date = models.DateField()
    status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default='active'
    )
    franchise_referral_code = models.CharField(max_length=20,null=True,blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.franchise_code} - {self.franchise_name}"
    
    

    
       
UNIT_CHOICES = (
    ('pcs', 'Pieces'),
    ('kg', 'Kilogram'),
    ('gm', 'Gram'),
    ('ltr', 'Litre'),
    ('ml', 'Millilitre'),
    ('box', 'Box'),
    ('packet', 'Packet'),
    ('set', 'Set'),
)

class FranchisePlanItem(models.Model):
    franchise_plan = models.ForeignKey(
        FranchisePlan,
        on_delete=models.CASCADE,
        related_name='items'
    )
    item_name = models.CharField(max_length=200)
    quantity = models.DecimalField(max_digits=10, decimal_places=2)
    unit = models.CharField(max_length=20, choices=UNIT_CHOICES)