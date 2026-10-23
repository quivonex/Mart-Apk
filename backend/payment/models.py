from decimal import Decimal

from django.db import models

from django.db import transaction
from django.db import models
from django.conf import settings

from real_estate.models import Property, User


class PaymentSetting(models.Model):

    COMPANY_REGISTRATION = "company_registration"

    PAYMENT_TYPE_CHOICES = (
        (
            COMPANY_REGISTRATION,
            "Company Registration"
        ),
    )

    payment_type = models.CharField(
        max_length=50,
        choices=PAYMENT_TYPE_CHOICES,
        unique=True
    )

    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    is_active = models.BooleanField(
        default=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):

        return (
            f"{self.get_payment_type_display()} "
            f"- ₹{self.amount}"
        )

      
        
        
class RazorpayPayment(models.Model):

    PAYMENT_STATUS_CHOICES = (
        ("created", "Created"),
        ("pending", "Pending"),
        ("success", "Success"),
        ("failed", "Failed"),
        ("refunded", "Refunded"),
    )

    order = models.OneToOneField(
        "shiprocket.ShipOrder",
        on_delete=models.CASCADE,
        related_name="razorpay_payment"
    )

    razorpay_order_id = models.CharField(
        max_length=255,
        unique=True,
        null=True,
        blank=True
    )

    razorpay_payment_id = models.CharField(
        max_length=255,
        null=True,
        blank=True
    )

    razorpay_signature = models.CharField(
        max_length=500,
        null=True,
        blank=True
    )

    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    currency = models.CharField(
        max_length=10,
        default="INR"
    )

    status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default="created"
    )

    payment_method = models.CharField(
        max_length=50,
        null=True,
        blank=True
    )

    error_code = models.CharField(
        max_length=100,
        null=True,
        blank=True
    )

    error_description = models.TextField(
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return f"{self.order.order_number} - {self.status}"        
    
    
class PropertySubscriptionPlan(models.Model):
    name = models.CharField(max_length=100)
    days = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10,decimal_places=2)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "property_subscription_plans"

    def __str__(self):
        return f"{self.name} - {self.days} Days - ₹{self.price}"    
    
    
class PropertySubscriptionPayment(models.Model):

    STATUS_CHOICES = [("created", "Created"),("paid", "Paid"),("failed", "Failed"),]
    property = models.ForeignKey(Property,on_delete=models.CASCADE,related_name="subscription_payments")
    plan = models.ForeignKey(PropertySubscriptionPlan,on_delete=models.PROTECT, related_name="payments")
    user = models.ForeignKey(User,on_delete=models.CASCADE,related_name="property_subscription_payments")
    amount = models.DecimalField(max_digits=10,decimal_places=2)
    razorpay_order_id = models.CharField(max_length=100,unique=True,blank=True,null=True)
    razorpay_payment_id = models.CharField(max_length=100,blank=True,null=True)
    status = models.CharField(max_length=20,choices=STATUS_CHOICES,default="created")
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(blank=True,null=True)
    class Meta:
        db_table = "property_subscription_payments"    
        
        
        
        
        
        
        
class CustomerSubscriptionPlan(models.Model):
    name = models.CharField(max_length=100)
    price = models.DecimalField(max_digits=10,decimal_places=2)
    enquiry_limit = models.PositiveIntegerField(default=0)
    duration_days = models.PositiveIntegerField(default=30)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name        
    
    
class CustomerSubscription(models.Model):

    user = models.ForeignKey(User,on_delete=models.CASCADE,related_name="customer_subscriptions")
    plan = models.ForeignKey(CustomerSubscriptionPlan,on_delete=models.PROTECT,related_name="subscriptions")
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    enquiry_limit = models.PositiveIntegerField(default=0)
    enquiry_used = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user} - {self.plan.name}"

    @property
    def remaining_enquiries(self):
        return max(
            self.enquiry_limit - self.enquiry_used,
            0
        )    
        
        
class CustomerSubscriptionPayment(models.Model):

    STATUS_CHOICES = (
        ("created", "Created"),
        ("success", "Success"),
        ("failed", "Failed"),
    )

    user = models.ForeignKey(User,on_delete=models.CASCADE,related_name="subscription_payments")
    plan = models.ForeignKey(CustomerSubscriptionPlan,on_delete=models.PROTECT,related_name="payments")
    razorpay_order_id = models.CharField(max_length=255,unique=True)
    razorpay_payment_id = models.CharField(max_length=255,blank=True,null=True)
    razorpay_signature = models.CharField(max_length=500,blank=True,null=True)
    amount = models.DecimalField(max_digits=10,decimal_places=2)
    status = models.CharField(max_length=20,choices=STATUS_CHOICES,default="created")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user} - {self.razorpay_order_id}"        